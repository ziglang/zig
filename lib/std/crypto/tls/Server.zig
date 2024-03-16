const std = @import("../../std.zig");
const tls = std.crypto.tls;
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const io = std.io;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;
const Allocator = std.mem.Allocator;

stream: tls.Stream,
options: Options,

const Self = @This();

/// Initiates a TLS handshake and establishes a TLSv1.3 session
pub fn init(stream: std.io.AnyStream, options: Options) !Self {
    var transcript_hash: tls.MultiHash = .{};
    var stream_ = tls.Stream{
        .stream = stream,
        .is_client = false,
        .transcript_hash = &transcript_hash,
    };
    var res = Self{ .stream = stream_, .options = options };
    const client_hello = try res.recv_hello(&stream_);
    _ = client_hello;

    var command = Command{ .recv_hello = {} };
    while (command != .none) command = try res.next(command);

    return res;
}

/// Executes handshake command and returns next one.
pub fn next(self: *Self, command: Command) !Command {
    var stream = &self.stream;

    switch (command) {
        .recv_hello => {
            const client_hello = try self.recv_hello();

            return .{ .send_hello = client_hello };
        },
        .send_hello => |client_hello| {
            try self.send_hello(client_hello);

            const scheme = client_hello.sig_scheme;
            // > if the client sends a non-empty session ID,
            // > the server MUST send the change_cipher_spec
            if (client_hello.session_id_len > 0) return .{ .send_change_cipher_spec = scheme };

            return .{ .send_encrypted_extensions = scheme };
        },
        .send_change_cipher_spec => |scheme| {
            try stream.changeCipherSpec();

            return .{ .send_encrypted_extensions = scheme };
        },
        .send_encrypted_extensions => |scheme| {
            try self.send_encrypted_extensions();

            return .{ .send_certificate = scheme };
        },
        .send_certificate => |scheme| {
            try self.send_certificate();

            var cert_verify = Command.CertificateVerify{ .scheme = scheme, .salt = undefined };
            crypto.random.bytes(&cert_verify.salt);

            return .{ .send_certificate_verify = cert_verify };
        },
        .send_certificate_verify => |cert_verify| {
            try self.send_certificate_verify(cert_verify);
            return .{ .send_finished = {} };
        },
        .send_finished => {
            try self.send_finished();
            return .{ .recv_finished = {} };
        },
        .recv_finished => {
            try self.recv_finished();
            return .{ .none = {} };
        },
        .none => return .{ .none = {} },
    }
}

pub fn recv_hello(self: *Self) !ClientHello {
    var stream = &self.stream;
    var reader = stream.reader();

    try stream.expectInnerPlaintext(.handshake, .client_hello);

    _ = try stream.read(tls.Version);
    var client_random: [32]u8 = undefined;
    try reader.readNoEof(&client_random);

    var session_id: [tls.ClientHello.session_id_max_len]u8 = undefined;
    const session_id_len = try stream.read(u8);
    if (session_id_len > tls.ClientHello.session_id_max_len)
        return stream.writeError(.illegal_parameter);
    try reader.readNoEof(session_id[0..session_id_len]);

    const cipher_suite: tls.CipherSuite = brk: {
        var cipher_suite_iter = try stream.iterator(u16, tls.CipherSuite);
        var res: ?tls.CipherSuite = null;
        while (try cipher_suite_iter.next()) |suite| {
            for (self.options.cipher_suites) |s| {
                if (s == suite and res == null) res = s;
            }
        }
        if (res == null) return stream.writeError(.illegal_parameter);
        break :brk res.?;
    };
    stream.transcript_hash.?.setActive(cipher_suite);

    {
        var compression_methods: [2]u8 = undefined;
        try reader.readNoEof(&compression_methods);
        if (!std.mem.eql(u8, &compression_methods, &[_]u8{ 1, 0 }))
            return stream.writeError(.illegal_parameter);
    }

    var tls_version: ?tls.Version = null;
    var key_share: ?tls.KeyShare = null;
    var ec_point_format: ?tls.EcPointFormat = null;
    var sig_scheme: ?tls.SignatureScheme = null;

    var extension_iter = try stream.extensions();
    while (try extension_iter.next()) |ext| {
        switch (ext.type) {
            .supported_versions => {
                if (tls_version != null) return stream.writeError(.illegal_parameter);
                var versions_iter = try stream.iterator(u8, tls.Version);
                while (try versions_iter.next()) |v| {
                    if (v == .tls_1_3) tls_version = v;
                }
            },
            // TODO: use supported_groups instead
            .key_share => {
                if (key_share != null) return stream.writeError(.illegal_parameter);

                var key_share_iter = try stream.iterator(u16, tls.KeyShare);
                while (try key_share_iter.next()) |ks| {
                    switch (ks) {
                        .x25519 => key_share = ks,
                        else => {},
                    }
                }
            },
            .ec_point_formats => {
                var format_iter = try stream.iterator(u8, tls.EcPointFormat);
                while (try format_iter.next()) |f| {
                    if (f == .uncompressed) ec_point_format = .uncompressed;
                }
            },
            .signature_algorithms => {
                var algos_iter = try stream.iterator(u16, tls.SignatureScheme);
                while (try algos_iter.next()) |algo| {
                    if (algo == .rsa_pss_rsae_sha256) sig_scheme = algo;
                }
            },
            else => {
                try reader.skipBytes(ext.len, .{});
            },
        }
    }

    if (tls_version != .tls_1_3) return stream.writeError(.protocol_version);
    if (key_share == null) return stream.writeError(.missing_extension);
    if (ec_point_format == null) return stream.writeError(.missing_extension);
    if (sig_scheme == null) return stream.writeError(.missing_extension);

    var server_random: [32]u8 = undefined;
    crypto.random.bytes(&server_random);

    const key_pair = .{
        .x25519 = crypto.dh.X25519.KeyPair.create(server_random) catch unreachable,
    };

    return .{
        .random = client_random,
        .session_id_len = session_id_len,
        .session_id = session_id,
        .cipher_suite = cipher_suite,
        .key_share = key_share.?,
        .sig_scheme = sig_scheme.?,
        .server_random = server_random,
        .server_pair = key_pair,
    };
}

pub fn send_hello(self: *Self, client_hello: ClientHello) !void {
    var stream = &self.stream;
    const key_pair = client_hello.server_pair;

    const hello = tls.ServerHello{
        .random = client_hello.server_random,
        .session_id = &client_hello.session_id,
        .cipher_suite = client_hello.cipher_suite,
        .extensions = &.{
            .{ .supported_versions = &[_]tls.Version{.tls_1_3} },
            .{ .key_share = &[_]tls.KeyShare{key_pair.toKeyShare()} },
        },
    };
    stream.version = .tls_1_2;
    _ = try stream.write(tls.Handshake, .{ .server_hello = hello });
    try stream.flush();

    const shared_key = switch (client_hello.key_share) {
        .x25519_kyber768d00 => |ks| brk: {
            const T = tls.NamedGroupT(.x25519_kyber768d00);
            const pair: tls.X25519Kyber768Draft.KeyPair = key_pair.x25519_kyber768d00;
            const shared_point = T.X25519.scalarmult(
                ks.x25519,
                pair.x25519.secret_key,
            ) catch return stream.writeError(.decrypt_error);
            // pair.kyber768d00.secret_key
            // ks.kyber768d00
            const encaps = ks.kyber768d00.encaps(null).ciphertext;

            break :brk &(shared_point ++ encaps);
        },
        .x25519 => |ks| brk: {
            const shared_point = tls.NamedGroupT(.x25519).scalarmult(
                key_pair.x25519.secret_key,
                ks,
            ) catch return stream.writeError(.decrypt_error);
            break :brk &shared_point;
        },
        .secp256r1 => |ks| brk: {
            const mul = ks.p.mulPublic(
                key_pair.secp256r1.secret_key.bytes,
                .big,
            ) catch return stream.writeError(.decrypt_error);
            break :brk &mul.affineCoordinates().x.toBytes(.big);
        },
        else => return stream.writeError(.illegal_parameter),
    };

    const hello_hash = stream.transcript_hash.?.peek();
    const handshake_cipher = tls.HandshakeCipher.init(
        client_hello.cipher_suite,
        shared_key,
        hello_hash,
    ) catch
        return stream.writeError(.illegal_parameter);
    stream.cipher = .{ .handshake = handshake_cipher };
}

pub fn send_encrypted_extensions(self: *Self) !void {
    var stream = &self.stream;
    _ = try stream.write(tls.Handshake, .{ .encrypted_extensions = &.{} });
    try stream.flush();
}

pub fn send_certificate(self: *Self) !void {
    var stream = &self.stream;
    _ = try self.stream.write(tls.Handshake, .{ .certificate = self.options.certificate });
    try stream.flush();
}

pub fn send_certificate_verify(self: *Self, verify: Command.CertificateVerify) !void {
    var stream = &self.stream;

    const digest = stream.transcript_hash.?.peek();
    const sig_content = tls.sigContent(digest);

    const key = self.options.certificate_key;
    const cert_buf = Certificate{ .buffer = self.options.certificate.entries[0].data, .index = 0 };
    const cert = cert_buf.parse() catch return stream.writeError(.bad_certificate);

    const signature: []const u8 = switch (verify.scheme) {
        // inline .ecdsa_secp256r1_sha256,
        // .ecdsa_secp384r1_sha384,
        // => |comptime_scheme| {
        //     if (cert.pub_key_algo != .X9_62_id_ecPublicKey)
        //         return stream.writeError(.bad_certificate);
        //     const Ecdsa = comptime_scheme.Ecdsa();
        //     const sig = Ecdsa.Signature.fromDer(sig_bytes) catch
        //         return stream.writeError(.decode_error);
        //     const key = Ecdsa.PublicKey.fromSec1(cert.pubKey()) catch
        //         return stream.writeError(.decode_error);
        //     sig.verify(sig_content, key) catch return stream.writeError(.bad_certificate);
        // },
        inline .rsa_pss_rsae_sha256,
        .rsa_pss_rsae_sha384,
        .rsa_pss_rsae_sha512,
        => |comptime_scheme| brk: {
            if (cert.pub_key_algo != .rsaEncryption)
                return stream.writeError(.bad_certificate);

            const Hash = comptime_scheme.Hash();
            const rsa = Certificate.rsa;
            // if (!std.mem.eql(u8, cert.pubKey(), key.public))
            //     return stream.writeError(.bad_certificate);

            switch (key.public.n.bits() / 8) {
                inline 128, 256, 512 => |modulus_length| {
                    break :brk &(rsa.PSSSignature.sign(
                        modulus_length,
                        sig_content,
                        Hash,
                        key,
                       verify.salt[0..Hash.digest_length].*,
                    ) catch return stream.writeError(.bad_certificate));
                },
                else => return stream.writeError(.bad_certificate),
            }
        },
        // inline .ed25519 => |comptime_scheme| {
        //     if (cert.pub_key_algo != .curveEd25519)
        //         return stream.writeError(.bad_certificate);
        //     const Eddsa = comptime_scheme.Eddsa();
        //     if (sig_content.len != Eddsa.Signature.encoded_length)
        //         return stream.writeError(.decode_error);
        //     const sig = Eddsa.Signature.fromBytes(sig_bytes[0..Eddsa.Signature.encoded_length].*);
        //     if (cert.pubKey().len != Eddsa.PublicKey.encoded_length)
        //         return stream.writeError(.decode_error);
        //     const key = Eddsa.PublicKey.fromBytes(cert.pubKey()[0..Eddsa.PublicKey.encoded_length].*) catch
        //         return stream.writeError(.bad_certificate);
        //     sig.verify(sig_content, key) catch return stream.writeError(.bad_certificate);
        // },
        else => {
            return stream.writeError(.bad_certificate);
        },
    };

    _ = try self.stream.write(tls.Handshake, .{ .certificate_verify = tls.CertificateVerify{
        .algorithm = .rsa_pss_rsae_sha256,
        .signature = signature,
    } });
    try stream.flush();
}

pub fn send_finished(self: *Self) !void {
    var stream = &self.stream;
    const verify_data = switch (stream.cipher.handshake) {
        inline .aes_256_gcm_sha384,
        => |v| brk: {
            const T = @TypeOf(v);
            const secret = v.server_finished_key;
            const transcript_hash = stream.transcript_hash.?.peek();

            break :brk tls.hmac(T.Hmac, transcript_hash, secret);
        },
        else => return stream.writeError(.illegal_parameter),
    };
    _ = try stream.write(tls.Handshake, .{ .finished = &verify_data });
    try stream.flush();
}

pub fn recv_finished(self: *Self) !void {
    var stream = &self.stream;
    var reader = stream.reader();

    const handshake_hash = stream.transcript_hash.?.peek();

    const application_cipher = tls.ApplicationCipher.init(
        stream.cipher.handshake,
        handshake_hash,
    );

    const expected = switch (stream.cipher.handshake) {
        inline else => |p| brk: {
            const P = @TypeOf(p);
            const digest = stream.transcript_hash.?.peek();
            break :brk &tls.hmac(P.Hmac, digest, p.client_finished_key);
        },
    };

    try stream.expectInnerPlaintext(.handshake, .finished);
    const actual = stream.view;
    try reader.skipBytes(stream.view.len, .{});

    if (!mem.eql(u8, expected, actual)) return stream.writeError(.decode_error);

    stream.content_type = .application_data;
    stream.handshake_type = null;
    stream.cipher = .{ .application = application_cipher };
    stream.transcript_hash = null;
}

pub const Options = struct {
    /// List of potential cipher suites in descending order of preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    certificate: tls.Certificate,
    certificate_key: Certificate.rsa.PrivateKey,
};

/// A command to send or receive a single message. Allows testing `advance` on a single thread.
pub const Command = union(enum) {
    recv_hello: void,
    send_hello: ClientHello,
    send_change_cipher_spec: tls.SignatureScheme,
    send_encrypted_extensions: tls.SignatureScheme,
    send_certificate: tls.SignatureScheme,
    send_certificate_verify: CertificateVerify,
    send_finished: void,
    recv_finished: void,
    none: void,

    pub const CertificateVerify = struct {
        scheme: tls.SignatureScheme,
        salt: [tls.MultiHash.max_digest_len]u8,
    };
};

pub const ClientHello = struct {
    random: [32]u8,
    session_id_len: u8,
    session_id: [32]u8,
    cipher_suite: tls.CipherSuite,
    key_share: tls.KeyShare,
    sig_scheme: tls.SignatureScheme,
    server_random: [32]u8,
    /// active member MUST match `key_share`
    server_pair: tls.KeyPair,
};

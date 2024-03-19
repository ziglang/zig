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
    const stream_ = tls.Stream{
        .stream = stream,
        .is_client = false,
        .transcript_hash = &transcript_hash,
    };
    var res = Self{ .stream = stream_, .options = options };

    // Verify that the certificate key matches the certificate.
    const cert_buf = Certificate{ .buffer = options.certificate.entries[0].data, .index = 0 };
    // TODO: don't reparse cert in send_certificate_verify
    const cert = try cert_buf.parse();
    const expected: std.meta.Tag(Options.CertificateKey) = switch (cert.pub_key_algo) {
        .rsaEncryption => .rsa,
        .X9_62_id_ecPublicKey => |curve| switch (curve) {
            .X9_62_prime256v1 => .ecdsa256,
            .secp384r1 => .ecdsa384,
            else => return error.UnsupportedCertificateSignature,
        },
        .curveEd25519 => .ed25519,
    };
    if (expected != options.certificate_key) return error.CertificateKeyMismatch;
    // TODO: verify private key corresponds to public key

    var command = initial_command();
    while (command != .none) {
        command = res.next(command) catch |err| switch (err) {
            // Prevent replay attacks in later handshake stages.
            error.ConnectionResetByPeer => initial_command(),
            else => return err,
        };
    }

    return res;
}

inline fn initial_command() Command {
    var res = Command{ .recv_hello = undefined };
    crypto.random.bytes(&res.recv_hello.server_random);
    crypto.random.bytes(&res.recv_hello.keygen_seed);

    return res;
}

/// Executes handshake command and returns next one.
pub fn next(self: *Self, command: Command) !Command {
    var stream = &self.stream;

    switch (command) {
        .recv_hello => |random| {
            const client_hello = try self.recv_hello(random);

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

pub fn recv_hello(self: *Self, random: Command.Random) !ClientHello {
    var stream = &self.stream;
    var reader = stream.any().reader();

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
                    for (self.options.key_shares) |s| {
                        if (ks == s and key_share == null) key_share = ks;
                    }
                }
                if (key_share == null) return stream.writeError(.decode_error);
            },
            .ec_point_formats => {
                var format_iter = try stream.iterator(u8, tls.EcPointFormat);
                while (try format_iter.next()) |f| {
                    if (f == .uncompressed) ec_point_format = .uncompressed;
                }
                if (ec_point_format == null) return stream.writeError(.decode_error);
            },
            .signature_algorithms => {
                const acceptable = switch (self.options.certificate_key) {
                    .rsa => &[_]tls.SignatureScheme{
                        .rsa_pss_rsae_sha384,
                        .rsa_pss_rsae_sha256,
                    },
                    .ecdsa256 => &[_]tls.SignatureScheme{.ecdsa_secp256r1_sha256},
                    .ecdsa384 => &[_]tls.SignatureScheme{.ecdsa_secp384r1_sha384},
                    .ed25519 => &[_]tls.SignatureScheme{.ed25519},
                };
                var algos_iter = try stream.iterator(u16, tls.SignatureScheme);
                while (try algos_iter.next()) |algo| {
                    for (acceptable) |a| {
                        if (algo == a and sig_scheme == null) sig_scheme = algo;
                    }
                }
                if (sig_scheme == null) return stream.writeError(.decode_error);
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

    const key_pair = switch (key_share.?) {
        inline .secp256r1,
        .secp384r1,
        .x25519,
        => |_, tag| brk: {
            const T = tls.NamedGroupT(tag).KeyPair;
            const pair = T.create(random.keygen_seed[0..T.seed_length].*) catch unreachable;
            break :brk @unionInit(tls.KeyPair, @tagName(tag), pair);
        },
        else => return stream.writeError(.decode_error),
    };

    return .{
        .random = client_random,
        .session_id_len = session_id_len,
        .session_id = session_id,
        .cipher_suite = cipher_suite,
        .key_share = key_share.?,
        .sig_scheme = sig_scheme.?,
        .server_random = random.server_random,
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
        .x25519 => |ks| brk: {
            const shared_point = tls.NamedGroupT(.x25519).scalarmult(
                key_pair.x25519.secret_key,
                ks,
            ) catch return stream.writeError(.decrypt_error);
            break :brk &shared_point;
        },
        inline .secp256r1, .secp384r1 => |ks, tag| brk: {
            const key = @field(key_pair, @tagName(tag));
            const mul = ks.p.mulPublic(key.secret_key.bytes, .big) catch
                return stream.writeError(.decrypt_error);
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

    const signature: []const u8 = switch (verify.scheme) {
        inline .ecdsa_secp256r1_sha256, .ecdsa_secp384r1_sha384 => |comptime_scheme| brk: {
            const Ecdsa = comptime_scheme.Ecdsa();
            const key = switch (comptime_scheme) {
                .ecdsa_secp256r1_sha256 => self.options.certificate_key.ecdsa256,
                .ecdsa_secp384r1_sha384 => self.options.certificate_key.ecdsa384,
                else => unreachable,
            };

            var signer = Ecdsa.Signer.init(key, verify.salt[0..Ecdsa.noise_length].*);
            signer.update(sig_content);
            const sig = signer.finalize() catch return stream.writeError(.internal_error);
            break :brk &sig.toBytes();
        },
        inline .rsa_pss_rsae_sha256,
        .rsa_pss_rsae_sha384,
        .rsa_pss_rsae_sha512,
        => |comptime_scheme| brk: {
            const Hash = comptime_scheme.Hash();
            const key = self.options.certificate_key.rsa;

            switch (key.public.n.bits() / 8) {
                inline 128, 256, 512 => |modulus_length| {
                    const sig = Certificate.rsa.PSSSignature.sign(
                        modulus_length,
                        sig_content,
                        Hash,
                        key,
                        verify.salt[0..Hash.digest_length].*,
                    ) catch return stream.writeError(.bad_certificate);
                    break :brk &sig;
                },
                else => return stream.writeError(.bad_certificate),
            }
        },
        .ed25519 => brk: {
            const Ed25519 = crypto.sign.Ed25519;
            const key = self.options.certificate_key.ed25519;

            const pub_key = brk2: {
                const cert_buf = Certificate{ .buffer = self.options.certificate.entries[0].data, .index = 0 };
                const cert = try cert_buf.parse();
                const expected_len = Ed25519.PublicKey.encoded_length;
                if (cert.pubKey().len != expected_len) return stream.writeError(.bad_certificate);
                break :brk2 Ed25519.PublicKey.fromBytes(cert.pubKey()[0..expected_len].*) catch
                    return stream.writeError(.bad_certificate);
            };
            const nonce: Ed25519.CompressedScalar = verify.salt[0..Ed25519.noise_length].*;

            const key_pair = Ed25519.KeyPair{ .public_key = pub_key, .secret_key = key };
            const sig = key_pair.sign(sig_content, nonce) catch return stream.writeError(.internal_error);
            break :brk &sig.toBytes();
        },
        else => {
            return stream.writeError(.bad_certificate);
        },
    };

    _ = try self.stream.write(tls.Handshake, .{ .certificate_verify = tls.CertificateVerify{
        .algorithm = verify.scheme,
        .signature = signature,
    } });
    try stream.flush();
}

pub fn send_finished(self: *Self) !void {
    var stream = &self.stream;
    const verify_data = switch (stream.cipher.handshake) {
        inline else => |v| brk: {
            const T = @TypeOf(v);
            const secret = v.server_finished_key;
            const transcript_hash = stream.transcript_hash.?.peek();

            break :brk &tls.hmac(T.Hmac, transcript_hash, secret);
        },
    };
    _ = try stream.write(tls.Handshake, .{ .finished = verify_data });
    try stream.flush();
}

pub fn recv_finished(self: *Self) !void {
    var stream = &self.stream;
    var reader = stream.any().reader();

    const handshake_hash = stream.transcript_hash.?.peek();

    const application_cipher = tls.ApplicationCipher.init(stream.cipher.handshake, handshake_hash);

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

pub const ReadError = anyerror;
pub const WriteError = anyerror;

/// Reads next application_data message.
pub fn readv(self: *Self, buffers: []const std.os.iovec) ReadError!usize {
    var stream = &self.stream;

    if (stream.eof()) return 0;

    while (stream.view.len == 0) {
        const inner_plaintext = try stream.readInnerPlaintext();
        switch (inner_plaintext.type) {
            .application_data => {},
            .alert => {},
            else => return stream.writeError(.unexpected_message),
        }
    }
    return try self.stream.readv(buffers);
}

pub fn writev(self: *Self, iov: []const std.os.iovec_const) WriteError!usize {
    if (self.stream.eof()) return 0;

    const res = try self.stream.writev(iov);
    try self.stream.flush();
    return res;
}

pub fn close(self: *Self) void {
    self.stream.close();
}

pub const GenericStream = std.io.GenericStream(*Self, ReadError, readv, WriteError, writev, close);

pub fn any(self: *Self) GenericStream {
    return .{ .context = self };
}

pub const Options = struct {
    /// List of potential cipher suites in descending order of preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    /// Types of shared keys to accept from client.
    key_shares: []const tls.NamedGroup = &tls.supported_groups,
    /// Certificate(s) to send in `send_certificate` messages.
    certificate: tls.Certificate,
    /// Key to use in `send_certificate_verify`. Must match `certificate.parse().pub_key_algo`.
    certificate_key: CertificateKey,

    pub const CertificateKey = union(enum) {
        rsa: crypto.Certificate.rsa.SecretKey,
        ecdsa256: tls.NamedGroupT(.secp256r1).SecretKey,
        ecdsa384: tls.NamedGroupT(.secp384r1).SecretKey,
        ed25519: crypto.sign.Ed25519.SecretKey,
    };
};

/// A command to send or receive a single message. Allows deterministically
/// testing `advance` on a single thread.
pub const Command = union(enum) {
    recv_hello: Random,
    send_hello: ClientHello,
    send_change_cipher_spec: tls.SignatureScheme,
    send_encrypted_extensions: tls.SignatureScheme,
    send_certificate: tls.SignatureScheme,
    send_certificate_verify: CertificateVerify,
    send_finished: void,
    recv_finished: void,
    none: void,

    pub const Random = struct {
        server_random: [32]u8,
        keygen_seed: [tls.NamedGroupT(.secp384r1).KeyPair.seed_length]u8,
    };

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
    /// Everything needed to generate a shared secret and send ciphertext to the client
    /// so it can do the same.
    /// Active member MUST match `key_share`.
    server_pair: tls.KeyPair,
};

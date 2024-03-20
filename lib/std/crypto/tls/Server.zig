const std = @import("../../std.zig");
const tls = std.crypto.tls;
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const io = std.io;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;
const Allocator = std.mem.Allocator;

tls_stream: tls.Stream,
key_logger: tls.KeyLogger,

pub const Options = struct {
    /// List of potential cipher suites in descending order of preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    /// Types of shared keys to accept from client.
    key_shares: []const tls.NamedGroup = &tls.supported_groups,
    /// Certificate(s) to send in `send_certificate` messages.
    /// The first entry will be used for verification.
    certificate: tls.Certificate = .{},
    /// Secret key corresponding to `certificate.entries[0]` to use for certificate verification.
    certificate_key: CertificateKey = .none,
    /// Writer to log shared secrets for traffic decryption in SSLKEYLOGFILE format.
    key_log: std.io.AnyWriter = std.io.null_writer.any(),

    pub const CertificateKey = union(enum) {
        none: void,
        rsa: crypto.Certificate.rsa.SecretKey,
        ecdsa256: tls.NamedGroupT(.secp256r1).SecretKey,
        ecdsa384: tls.NamedGroupT(.secp384r1).SecretKey,
        ed25519: crypto.sign.Ed25519.SecretKey,
    };
};

const Server = @This();

/// Initiates a TLS handshake and establishes a TLSv1.3 session
pub fn init(any_stream: std.io.AnyStream, options: Options) !Server {
    const hs = Handshake.init(any_stream, options);
    return try hs.hanshake();
}

pub const ReadError = anyerror;
pub const WriteError = anyerror;

/// Reads next application_data message.
pub fn readv(self: *Server, buffers: []const std.os.iovec) ReadError!usize {
    var s = &self.tls_stream;

    if (s.eof()) return 0;

    while (s.view.len == 0) {
        const inner_plaintext = try s.readInnerPlaintext();
        switch (inner_plaintext.type) {
            .application_data => {},
            .alert => {},
            else => return s.writeError(.unexpected_message),
        }
    }
    return try self.tls_stream.readv(buffers);
}

pub fn writev(self: *Server, iov: []const std.os.iovec_const) WriteError!usize {
    if (self.tls_stream.eof()) return 0;

    const res = try self.tls_stream.writev(iov);
    try self.tls_stream.flush();
    return res;
}

pub fn close(self: *Server) void {
    self.tls_stream.close();
}

pub const GenericStream = std.io.GenericStream(*Server, ReadError, readv, WriteError, writev, close);

pub fn stream(self: *Server) GenericStream {
    return .{ .context = self };
}

pub const Handshake = struct {
    tls_stream: tls.Stream,
    /// Running hash of handshake messages for cryptographic functions
    transcript_hash: tls.MultiHash = .{},
    options: Options,
    cert: ?Certificate.Parsed = null,

    server_random: [32]u8,
    keygen_seed: [tls.NamedGroupT(.secp384r1).KeyPair.seed_length]u8,
    certificate_verify_salt: [tls.MultiHash.max_digest_len]u8,

    /// Next command to execute
    command: Command = .recv_hello,

    /// Defined after `recv_hello`
    client_hello: ClientHello = undefined,
    /// Used to establish a shared secret. Defined after `recv_hello`
    key_pair: tls.KeyPair = undefined,

    pub const ClientHello = struct {
        random: [32]u8,
        session_id_len: u8,
        session_id: [32]u8,
        cipher_suite: tls.CipherSuite,
        key_share: tls.KeyShare,
        sig_scheme: tls.SignatureScheme,
    };

    /// A command to send or receive a single message.
    pub const Command = enum {
        recv_hello,
        send_hello,
        send_change_cipher_spec,
        send_encrypted_extensions,
        send_certificate,
        send_certificate_verify,
        send_finished,
        recv_finished,
        none,
    };

    /// Initializes members. Does NOT send any messages to `any_stream`.
    pub fn init(any_stream: std.io.AnyStream, options: Options) Handshake {
        const tls_stream = tls.Stream{ .stream = any_stream, .is_client = false };
        var res = Handshake{
            .tls_stream = tls_stream,
            .options = options,
            .random = undefined,
            .session_id = undefined,
            .key_pairs = undefined,
        };
        res.init_random();

        const certificates = options.certificate.entries;
        // Verify that the certificate key matches the root certificate.
        // This allows failing fast now instead of every client failing signature verification later.
        if (certificates.len > 0) {
            const cert_buf = Certificate{ .buffer = options.certificate.entries[0].data, .index = 0 };
            res.cert = try cert_buf.parse();
            const expected: std.meta.Tag(Options.CertificateKey) = switch (res.cert.pub_key_algo) {
                .rsaEncryption => .rsa,
                .X9_62_id_ecPublicKey => |curve| switch (curve) {
                    .X9_62_prime256v1 => .ecdsa256,
                    .secp384r1 => .ecdsa384,
                    else => return error.UnsupportedCertificateSignature,
                },
                .curveEd25519 => .ed25519,
            };
            if (expected != options.certificate_key) return error.CertificateKeyMismatch;

            // TODO: test private key matches cert public key
            // const test_msg = "hello";
            // switch (options.certificate_key) {
            //     .rsa => |key| {
            //         switch (key.n.bits() / 8) {
            //             inline 128, 256, 512 => |modulus_len| {
            //                 const enc = key.public.encrypt(modulus_len, test_msg);
            //                 const dec = key.decrypt(modulus_len, enc) catch return error.CertificateKeyMismatch;
            //                 if (!std.mem.eql(u8, test_msg, dec)) return error.CertificateKeyMismatch;
            //             },
            //             else => return error.CertificateKeyMismatch,
            //         }
            //     },
            //     inline .ecdsa256, .ecdsa384 => |comptime_scheme| {
            //     },
            //     .ed25519: crypto.sign.Ed25519.SecretKey,
            // }
        }

        return res;
    }

    inline fn init_random(self: *Handshake) void {
        crypto.random.bytes(&self.server_random);
        crypto.random.bytes(&self.keygen_seed);
        crypto.random.bytes(&self.certificate_verify_salt);
    }

    /// Executes handshake command and returns next one.
    pub fn next(self: *Handshake) !void {
        var s = &self.tls_stream;
        s.transcript_hash = &self.transcript_hash;

        self.command = switch (self.command) {
            .recv_hello => brk: {
                self.client_hello = try self.recv_hello();

                break: brk .send_hello;
            },
            .send_hello => brk: {
                try self.send_hello();

                // > if the client sends a non-empty session ID,
                // > the server MUST send the change_cipher_spec
                if (self.client_hello.session_id_len > 0) break :brk  .send_change_cipher_spec;

                break :brk .send_encrypted_extensions;
            },
            .send_change_cipher_spec => brk: {
                try s.changeCipherSpec();

                break :brk .send_encrypted_extensions;
            },
            .send_encrypted_extensions => brk: {
                try self.send_encrypted_extensions();

                break :brk .send_certificate;
            },
            .send_certificate => brk: {
                try self.send_certificate();

                break :brk .send_certificate_verify;
            },
            .send_certificate_verify => brk: {
                try self.send_certificate_verify();
                break :brk .send_finished;
            },
            .send_finished => brk: {
                try self.send_finished();
                break :brk .recv_finished;
            },
            .recv_finished => brk: {
                try self.recv_finished();
                break :brk .none;
            },
            .none => .none,
        };
    }

    pub fn recv_hello(self: *Handshake) !ClientHello {
        var s = &self.tls_stream;
        var reader = s.stream().reader();

        try s.expectInnerPlaintext(.handshake, .client_hello);

        _ = try s.read(tls.Version);
        var client_random: [32]u8 = undefined;
        try reader.readNoEof(&client_random);

        var session_id: [tls.ClientHello.session_id_max_len]u8 = undefined;
        const session_id_len = try s.read(u8);
        if (session_id_len > tls.ClientHello.session_id_max_len)
            return s.writeError(.illegal_parameter);
        try reader.readNoEof(session_id[0..session_id_len]);

        const cipher_suite: tls.CipherSuite = brk: {
            var cipher_suite_iter = try s.iterator(u16, tls.CipherSuite);
            var res: ?tls.CipherSuite = null;
            while (try cipher_suite_iter.next()) |suite| {
                for (self.options.cipher_suites) |cs| {
                    if (cs == suite and res == null) res = cs;
                }
            }
            if (res == null) return s.writeError(.illegal_parameter);
            break :brk res.?;
        };
        s.transcript_hash.?.setActive(cipher_suite);

        {
            var compression_methods: [2]u8 = undefined;
            try reader.readNoEof(&compression_methods);
            if (!std.mem.eql(u8, &compression_methods, &[_]u8{ 1, 0 }))
                return s.writeError(.illegal_parameter);
        }

        var tls_version: ?tls.Version = null;
        var key_share: ?tls.KeyShare = null;
        var ec_point_format: ?tls.EcPointFormat = null;
        var sig_scheme: ?tls.SignatureScheme = null;

        var extension_iter = try s.extensions();
        while (try extension_iter.next()) |ext| {
            switch (ext.type) {
                .supported_versions => {
                    if (tls_version != null) return s.writeError(.illegal_parameter);
                    var versions_iter = try s.iterator(u8, tls.Version);
                    while (try versions_iter.next()) |v| {
                        if (v == .tls_1_3) tls_version = v;
                    }
                },
                // TODO: use supported_groups instead
                .key_share => {
                    if (key_share != null) return s.writeError(.illegal_parameter);

                    var key_share_iter = try s.iterator(u16, tls.KeyShare);
                    while (try key_share_iter.next()) |ks| {
                        for (self.options.key_shares) |k| {
                            if (ks == k and key_share == null) key_share = ks;
                        }
                    }
                    if (key_share == null) return s.writeError(.decode_error);
                },
                .ec_point_formats => {
                    var format_iter = try s.iterator(u8, tls.EcPointFormat);
                    while (try format_iter.next()) |f| {
                        if (f == .uncompressed) ec_point_format = .uncompressed;
                    }
                    if (ec_point_format == null) return s.writeError(.decode_error);
                },
                .signature_algorithms => {
                    const acceptable = switch (self.options.certificate_key) {
                        .none => &[_]tls.SignatureScheme{}, // should be all of them
                        .rsa => &[_]tls.SignatureScheme{
                            .rsa_pss_rsae_sha384,
                            .rsa_pss_rsae_sha256,
                        },
                        .ecdsa256 => &[_]tls.SignatureScheme{.ecdsa_secp256r1_sha256},
                        .ecdsa384 => &[_]tls.SignatureScheme{.ecdsa_secp384r1_sha384},
                        .ed25519 => &[_]tls.SignatureScheme{.ed25519},
                    };
                    var algos_iter = try s.iterator(u16, tls.SignatureScheme);
                    while (try algos_iter.next()) |algo| {
                        if (self.options.certificate_key == .none) sig_scheme = algo;
                        for (acceptable) |a| {
                            if (algo == a and sig_scheme == null) sig_scheme = algo;
                        }
                    }
                    if (sig_scheme == null) return s.writeError(.decode_error);
                },
                else => {
                    try reader.skipBytes(ext.len, .{});
                },
            }
        }

        if (tls_version != .tls_1_3) return s.writeError(.protocol_version);
        if (key_share == null) return s.writeError(.missing_extension);
        if (ec_point_format == null) return s.writeError(.missing_extension);
        if (sig_scheme == null) return s.writeError(.missing_extension);

        self.key_pair = switch (key_share.?) {
            inline .secp256r1,
            .secp384r1,
            .x25519,
            => |_, tag| brk: {
                const T = tls.NamedGroupT(tag).KeyPair;
                const pair = T.create(self.keygen_seed[0..T.seed_length].*) catch unreachable;
                break :brk @unionInit(tls.KeyPair, @tagName(tag), pair);
            },
            else => return s.writeError(.decode_error),
        };

        return .{
            .random = client_random,
            .session_id_len = session_id_len,
            .session_id = session_id,
            .cipher_suite = cipher_suite,
            .key_share = key_share.?,
            .sig_scheme = sig_scheme.?,
        };
    }

    pub fn send_hello(self: *Handshake) !void {
        var s = &self.tls_stream;
        const key_pair = self.key_pair;
        const client_hello = self.client_hello;

        const hello = tls.ServerHello{
            .random = self.server_random,
            .session_id = &client_hello.session_id,
            .cipher_suite = client_hello.cipher_suite,
            .extensions = &.{
                .{ .supported_versions = &[_]tls.Version{.tls_1_3} },
                .{ .key_share = &[_]tls.KeyShare{key_pair.toKeyShare()} },
            },
        };
        s.version = .tls_1_2;
        _ = try s.write(tls.Handshake, .{ .server_hello = hello });
        try s.flush();

        const shared_key = switch (client_hello.key_share) {
            .x25519 => |ks| brk: {
                const shared_point = tls.NamedGroupT(.x25519).scalarmult(
                    key_pair.x25519.secret_key,
                    ks,
                ) catch return s.writeError(.decrypt_error);
                break :brk &shared_point;
            },
            inline .secp256r1, .secp384r1 => |ks, tag| brk: {
                const key = @field(key_pair, @tagName(tag));
                const mul = ks.p.mulPublic(key.secret_key.bytes, .big) catch
                    return s.writeError(.decrypt_error);
                break :brk &mul.affineCoordinates().x.toBytes(.big);
            },
            else => return s.writeError(.illegal_parameter),
        };

        const hello_hash = s.transcript_hash.?.peek();
        const handshake_cipher = tls.HandshakeCipher.init(
            client_hello.cipher_suite,
            shared_key,
            hello_hash,
            self.logger(),
        ) catch
            return s.writeError(.illegal_parameter);
        s.cipher = .{ .handshake = handshake_cipher };
    }

    pub fn send_encrypted_extensions(self: *Handshake) !void {
        var s = &self.tls_stream;
        _ = try s.write(tls.Handshake, .{ .encrypted_extensions = &.{} });
        try s.flush();
    }

    pub fn send_certificate(self: *Handshake) !void {
        var s = &self.tls_stream;
        _ = try self.tls_stream.write(tls.Handshake, .{ .certificate = self.options.certificate });
        try s.flush();
    }

    pub fn send_certificate_verify(self: *Handshake) !void {
        var s = &self.tls_stream;
        const salt = self.certificate_verify_salt;
        const scheme = self.client_hello.sig_scheme;

        const digest = s.transcript_hash.?.peek();
        const sig_content = tls.sigContent(digest);

        const signature: []const u8 = switch (scheme) {
            inline .ecdsa_secp256r1_sha256, .ecdsa_secp384r1_sha384 => |comptime_scheme| brk: {
                const Ecdsa = comptime_scheme.Ecdsa();
                const key = switch (comptime_scheme) {
                    .ecdsa_secp256r1_sha256 => self.options.certificate_key.ecdsa256,
                    .ecdsa_secp384r1_sha384 => self.options.certificate_key.ecdsa384,
                    else => unreachable,
                };

                var signer = Ecdsa.Signer.init(key, salt[0..Ecdsa.noise_length].*);
                signer.update(sig_content);
                const sig = signer.finalize() catch return s.writeError(.internal_error);
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
                            salt[0..Hash.digest_length].*,
                        ) catch return s.writeError(.bad_certificate);
                        break :brk &sig;
                    },
                    else => return s.writeError(.bad_certificate),
                }
            },
            .ed25519 => brk: {
                const Ed25519 = crypto.sign.Ed25519;
                const key = self.options.certificate_key.ed25519;

                const pub_key = brk2: {
                    const cert_buf = Certificate{ .buffer = self.options.certificate.entries[0].data, .index = 0 };
                    const cert = try cert_buf.parse();
                    const expected_len = Ed25519.PublicKey.encoded_length;
                    if (cert.pubKey().len != expected_len) return s.writeError(.bad_certificate);
                    break :brk2 Ed25519.PublicKey.fromBytes(cert.pubKey()[0..expected_len].*) catch
                        return s.writeError(.bad_certificate);
                };
                const nonce: Ed25519.CompressedScalar = salt[0..Ed25519.noise_length].*;

                const key_pair = Ed25519.KeyPair{ .public_key = pub_key, .secret_key = key };
                const sig = key_pair.sign(sig_content, nonce) catch return s.writeError(.internal_error);
                break :brk &sig.toBytes();
            },
            else => {
                return s.writeError(.bad_certificate);
            },
        };

        _ = try self.tls_stream.write(tls.Handshake, .{ .certificate_verify = tls.CertificateVerify{
            .algorithm = scheme,
            .signature = signature,
        } });
        try s.flush();
    }

    pub fn send_finished(self: *Handshake) !void {
        var s = &self.tls_stream;
        const verify_data = switch (s.cipher.handshake) {
            inline else => |v| brk: {
                const T = @TypeOf(v);
                const secret = v.server_finished_key;
                const transcript_hash = s.transcript_hash.?.peek();

                break :brk &tls.hmac(T.Hmac, transcript_hash, secret);
            },
        };
        _ = try s.write(tls.Handshake, .{ .finished = verify_data });
        try s.flush();
    }

    pub fn recv_finished(self: *Handshake) !void {
        var s = &self.tls_stream;
        var reader = s.stream().reader();

        const handshake_hash = s.transcript_hash.?.peek();

        const application_cipher = tls.ApplicationCipher.init(
            s.cipher.handshake,
            handshake_hash,
            self.logger(),
        );

        const expected = switch (s.cipher.handshake) {
            inline else => |p| brk: {
                const P = @TypeOf(p);
                const digest = s.transcript_hash.?.peek();
                break :brk &tls.hmac(P.Hmac, digest, p.client_finished_key);
            },
        };

        try s.expectInnerPlaintext(.handshake, .finished);
        const actual = s.view;
        try reader.skipBytes(s.view.len, .{});

        if (!mem.eql(u8, expected, actual)) return s.writeError(.decode_error);

        s.content_type = .application_data;
        s.handshake_type = null;
        s.cipher = .{ .application = application_cipher };
        s.transcript_hash = null;
    }

    /// Establishes a TLS connection on `tls_stream` and returns a Client.
    pub fn handshake(self: *Handshake) !Server {
        while (self.command != .none) self.next() catch |err| switch (err) {
            error.ConnectionResetByPeer => {
                // Prevent reply attacks
                self.command = .send_hello;
                self.init_random();
            },
            else => return err,
        };

        return Server{
            .tls_stream = self.tls_stream,
            .key_logger = .{
                .writer = self.options.key_log,
                .client_random = self.client_hello.random,
            },
        };
    }

    fn logger(self: *Handshake) tls.KeyLogger {
        return tls.KeyLogger{
            .client_random = self.client_hello.random,
            .writer = self.options.key_log,
        };
    }
};


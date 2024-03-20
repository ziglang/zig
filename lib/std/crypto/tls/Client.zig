const std = @import("../../std.zig");
const tls = std.crypto.tls;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const Certificate = crypto.Certificate;
const Allocator = std.mem.Allocator;

tls_stream: tls.Stream,
key_logger: tls.KeyLogger,

pub const Options = struct {
    /// Certificate messages may be up to 2^24-1 bytes long.
    /// Certificate verify messages may be up to 2^16-1 bytes long.
    /// This is the allocator to use for them.
    allocator: Allocator,
    /// Trusted certificate authority bundle used to authenticate server certificates.
    /// When null, server certificate and certificate_verify messages will be skipped.
    ca_bundle: ?Certificate.Bundle,
    /// Used to verify cerficate chain and for Server Name Indication.
    host: []const u8,
    /// List of cipher suites to advertise in order of descending preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    /// Minimum version to support.
    min_version: tls.Version = .tls_1_3,
    /// By default, reaching the end-of-stream when reading from the server will
    /// cause `error.TlsConnectionTruncated` to be returned, unless a close_notify
    /// message has been received. By setting this flag to `true`, instead, the
    /// end-of-stream will be forwarded to the application layer above TLS.
    /// This makes the application vulnerable to truncation attacks unless the
    /// application layer itself verifies that the amount of data received equals
    /// the amount of data expected, such as HTTP with the Content-Length header.
    allow_truncation_attacks: bool = false,
    /// Writer to log shared secrets for traffic decryption in SSLKEYLOGFILE format.
    key_log: std.io.AnyWriter = std.io.null_writer.any(),
};

const Client = @This();

/// Executes a TLSv1.3 handshake on `any_stream`.
pub fn init(any_stream: std.io.AnyStream, options: Options) !Client {
    const hs = Handshake.init(any_stream, options);
    return try hs.handshake();
}

pub const ReadError = anyerror;
pub const WriteError = anyerror;

/// Reads next application_data message.
pub fn readv(self: *Client, buffers: []const std.os.iovec) ReadError!usize {
    var s = &self.tls_stream;

    while (s.view.len == 0 and !s.eof()) {
        const inner_plaintext = try s.readInnerPlaintext();
        switch (inner_plaintext.type) {
            .handshake => {
                switch (inner_plaintext.handshake_type) {
                    // A multithreaded client could use these.
                    .new_session_ticket => {
                        try s.stream().reader().skipBytes(inner_plaintext.len, .{});
                    },
                    .key_update => {
                        switch (s.cipher.application) {
                            inline else => |*p| {
                                const P = @TypeOf(p.*);
                                p.server_secret = tls.hkdfExpandLabel(P.Hkdf, p.server_secret, "traffic upd", "", P.Hash.digest_length);
                                p.server_key = tls.hkdfExpandLabel(P.Hkdf, p.server_secret, "key", "", P.AEAD.key_length);
                                p.server_iv = tls.hkdfExpandLabel(P.Hkdf, p.server_secret, "iv", "", P.AEAD.nonce_length);
                                p.read_seq = 0;

                                var logger = &self.key_logger;
                                logger.server_update_n += 1;
                                logger.writer.print("SERVER_TRAFFIC_SECRET_{d}", .{logger.server_update_n}) catch {};
                                logger.writeLine("", &p.server_secret) catch {};
                            },
                        }
                        const update = try s.read(tls.KeyUpdate);
                        if (update == .update_requested) {
                            switch (s.cipher.application) {
                                inline else => |*p| {
                                    const P = @TypeOf(p.*);
                                    p.client_secret = tls.hkdfExpandLabel(P.Hkdf, p.client_secret, "traffic upd", "", P.Hash.digest_length);
                                    p.client_key = tls.hkdfExpandLabel(P.Hkdf, p.client_secret, "key", "", P.AEAD.key_length);
                                    p.client_iv = tls.hkdfExpandLabel(P.Hkdf, p.client_secret, "iv", "", P.AEAD.nonce_length);
                                    p.write_seq = 0;

                                    var logger = &self.key_logger;
                                    logger.client_update_n += 1;
                                    logger.writer.print("CLIENT_TRAFFIC_SECRET_{d}", .{logger.client_update_n}) catch {};
                                    logger.writeLine("", &p.client_secret) catch {};
                                },
                            }
                        }
                    },
                    else => return s.writeError(.unexpected_message),
                }
            },
            .alert => {},
            .application_data => {},
            else => return s.writeError(.unexpected_message),
        }
    }
    return try s.readv(buffers);
}

/// Writes application_data message and flushes stream.
pub fn writev(self: *Client, iov: []const std.os.iovec_const) WriteError!usize {
    if (self.tls_stream.eof()) return 0;

    const res = try self.tls_stream.writev(iov);
    try self.tls_stream.flush();
    return res;
}

pub fn close(self: *Client) void {
    self.tls_stream.close();
}

pub const GenericStream = std.io.GenericStream(*Client, ReadError, readv, WriteError, writev, close);

pub fn stream(self: *Client) GenericStream {
    return .{ .context = self };
}

pub const Handshake = struct {
    tls_stream: tls.Stream,
    /// Running hash of handshake messages for cryptographic functions
    transcript_hash: tls.MultiHash = .{},
    options: Options,

    client_random: [32]u8,
    /// Used in TLSv1.2. Always set for middlebox compatibility.
    session_id: [32]u8,
    /// One of these potential key pairs will be selected in `recv_hello`
    /// to establish a shared secret for encryption.
    key_pairs: KeyPairs,

    /// Next command to execute
    command: Command = .send_hello,

    /// Server certificate to later verify.
    /// `cert.certificate.buffer` is allocated
    cert: Certificate.Parsed = undefined,

    pub const KeyPairs = struct {
        secp256r1: Secp256r1,
        secp384r1: Secp384r1,
        x25519: X25519,

        const X25519 = tls.NamedGroupT(.x25519).KeyPair;
        const Secp256r1 = tls.NamedGroupT(.secp256r1).KeyPair;
        const Secp384r1 = tls.NamedGroupT(.secp384r1).KeyPair;

        pub fn init() @This() {
            var random_buffer: [
                    Secp256r1.seed_length +
                    Secp384r1.seed_length +
                    X25519.seed_length
            ]u8 = undefined;

            while (true) {
                crypto.random.bytes(&random_buffer);

                const split1 = Secp256r1.seed_length;
                const split2 = split1 + Secp384r1.seed_length;

                return initAdvanced(
                    random_buffer[0..split1].*,
                    random_buffer[split1..split2].*,
                    random_buffer[split2..].*,
                ) catch continue;
            }
        }

        pub fn initAdvanced(
            secp256r1_seed: [Secp256r1.seed_length]u8,
            secp384r1_seed: [Secp384r1.seed_length]u8,
            x25519_seed: [X25519.seed_length]u8,
        ) !@This() {
            return .{
                .secp256r1 = Secp256r1.create(secp256r1_seed) catch |err| switch (err) {
                    error.IdentityElement => return error.InsufficientEntropy, // Private key is all zeroes.
                },
                .secp384r1 = Secp384r1.create(secp384r1_seed) catch |err| switch (err) {
                    error.IdentityElement => return error.InsufficientEntropy, // Private key is all zeroes.
                },
                .x25519 = X25519.create(x25519_seed) catch |err| switch (err) {
                    error.IdentityElement => return error.InsufficientEntropy, // Private key is all zeroes.
                },
            };
        }
    };

    /// A command to send or receive a single message.
    pub const Command = enum {
        send_hello,
        recv_hello,
        recv_encrypted_extensions,
        recv_certificate_or_finished,
        recv_certificate_verify,
        recv_finished,
        send_change_cipher_spec,
        send_finished,
        none,
    };

    /// Initializes members. Does NOT send any messages to `any_stream`.
    pub fn init(any_stream: std.io.AnyStream, options: Options) Handshake {
        const tls_stream = tls.Stream{ .stream = any_stream, .is_client = true };
        var res = Handshake{
            .tls_stream = tls_stream,
            .options = options,
            .random = undefined,
            .session_id = undefined,
            .key_pairs = undefined,
        };
        res.init_random();

        return res;
    }

    inline fn init_random(self: *Handshake) void {
        self.key_pairs = KeyPairs.init();
        crypto.random.bytes(&self.client_random);
        crypto.random.bytes(&self.session_id);
    }

    /// Establishes a TLS connection on `tls_stream` and returns a Client.
    pub fn handshake(self: *Handshake) !Client {
        while (self.command != .none) self.next() catch |err| switch (err) {
            error.ConnectionResetByPeer => {
                // Prevent reply attacks
                self.command = .send_hello;
                self.init_random();
            },
            else => return err,
        };

        return Client{
            .tls_stream = self.tls_stream,
            .key_logger = .{
                .writer = self.options.key_log,
                .client_random = self.client_random,
            },
        };
    }

    /// Sends or receives exactly ONE handshake message on `tls_stream`.
    /// Sets `self.command` to next expected message.
    pub fn next(self: *Handshake) !void {
        var s = &self.tls_stream;
        s.transcript_hash = &self.transcript_hash;

        self.command = switch (self.command) {
            .send_hello => brk: {
                try self.send_hello();

                break :brk .recv_hello;
            },
            .recv_hello => brk: {
                try s.expectInnerPlaintext(.handshake, .server_hello);
                try self.recv_hello();

                break :brk .recv_encrypted_extensions;
            },
            .recv_encrypted_extensions => brk: {
                try s.expectInnerPlaintext(.handshake, .encrypted_extensions);
                try self.recv_encrypted_extensions();

                break :brk .recv_certificate_or_finished;
            },
            .recv_certificate_or_finished => brk: {
                const digest = s.transcript_hash.?.peek();
                const inner_plaintext = try s.readInnerPlaintext();
                if (inner_plaintext.type != .handshake) return s.writeError(.unexpected_message);
                switch (inner_plaintext.handshake_type) {
                    .certificate => {
                        self.cert = try self.recv_certificate();

                        break :brk .recv_certificate_verify;
                    },
                    .finished => {
                        if (self.options.ca_bundle != null)
                            return self.tls_stream.writeError(.certificate_required);

                        try self.recv_finished(digest);

                        break :brk .send_finished;
                    },
                    else => return self.tls_stream.writeError(.unexpected_message),
                }
            },
            .recv_certificate_verify => brk: {
                defer self.options.allocator.free(self.cert.certificate.buffer);

                const digest = s.transcript_hash.?.peek();
                try s.expectInnerPlaintext(.handshake, .certificate_verify);
                try self.recv_certificate_verify(digest);

                break :brk .recv_finished;
            },
            .recv_finished => brk: {
                const digest = s.transcript_hash.?.peek();
                try s.expectInnerPlaintext(.handshake, .finished);
                try self.recv_finished(digest);

                break :brk .send_change_cipher_spec;
            },
            .send_change_cipher_spec => brk: {
                try s.changeCipherSpec();

                break :brk .send_finished;
            },
            .send_finished => brk: {
                try self.send_finished();

                break :brk .none;
            },
            .none =>  .none,
        };
    }

    pub fn send_hello(self: *Handshake) !void {
        const hello = tls.ClientHello{
            .random = self.client_random,
            .session_id = &self.session_id,
            .cipher_suites = self.options.cipher_suites,
            .extensions = &.{
                .{ .server_name = &[_]tls.ServerName{.{ .host_name = self.options.host }} },
                .{ .ec_point_formats = &[_]tls.EcPointFormat{.uncompressed} },
                .{ .supported_groups = &tls.supported_groups },
                .{ .signature_algorithms = &tls.supported_signature_schemes },
                .{ .supported_versions = &[_]tls.Version{.tls_1_3} },
                .{ .key_share = &[_]tls.KeyShare{
                    .{ .secp256r1 = self.key_pairs.secp256r1.public_key },
                    .{ .secp384r1 = self.key_pairs.secp384r1.public_key },
                    .{ .x25519 = self.key_pairs.x25519.public_key },
                } },
            },
        };

        _ = try self.tls_stream.write(tls.Handshake, .{ .client_hello = hello });
        try self.tls_stream.flush();
    }

    pub fn recv_hello(self: *Handshake) !void {
        var s = &self.tls_stream;
        var r = s.stream().reader();

        // > The value of TLSPlaintext.legacy_record_version MUST be ignored by all implementations.
        _ = try s.read(tls.Version);
        var random: [32]u8 = undefined;
        try r.readNoEof(&random);
        if (mem.eql(u8, &random, &tls.ServerHello.hello_retry_request)) {
            // We already offered all our supported options and we aren't changing them.
            return s.writeError(.unexpected_message);
        }

        var session_id_buf: [tls.ClientHello.session_id_max_len]u8 = undefined;
        const session_id_len = try s.read(u8);
        if (session_id_len > tls.ClientHello.session_id_max_len)
            return s.writeError(.illegal_parameter);
        const session_id: []u8 = session_id_buf[0..session_id_len];
        try r.readNoEof(session_id);
        if (!mem.eql(u8, session_id, &self.session_id))
            return s.writeError(.illegal_parameter);

        const cipher_suite = try s.read(tls.CipherSuite);
        const compression_method = try s.read(u8);
        if (compression_method != 0) return s.writeError(.illegal_parameter);

        var supported_version: ?tls.Version = null;
        var shared_key: ?[]const u8 = null;

        var iter = try s.extensions();
        while (try iter.next()) |ext| {
            switch (ext.type) {
                .supported_versions => {
                    if (supported_version != null) return s.writeError(.illegal_parameter);
                    supported_version = try s.read(tls.Version);
                },
                .key_share => {
                    if (shared_key != null) return s.writeError(.illegal_parameter);
                    const named_group = try s.read(tls.NamedGroup);
                    const key_size = try s.read(u16);
                    switch (named_group) {
                        .x25519 => {
                            const T = tls.NamedGroupT(.x25519);
                            const expected_len = T.public_length;
                            if (key_size != expected_len) return s.writeError(.illegal_parameter);
                            var server_ks: [expected_len]u8 = undefined;
                            try r.readNoEof(&server_ks);

                            const mult = crypto.dh.X25519.scalarmult(
                                self.key_pairs.x25519.secret_key,
                                server_ks[0..expected_len].*,
                            ) catch return s.writeError(.illegal_parameter);
                            shared_key = &mult;
                        },
                        inline .secp256r1, .secp384r1 => |t| {
                            const T = tls.NamedGroupT(t);
                            const expected_len = T.PublicKey.uncompressed_sec1_encoded_length;
                            if (key_size != expected_len) return s.writeError(.illegal_parameter);

                            var server_ks: [expected_len]u8 = undefined;
                            try r.readNoEof(&server_ks);

                            const pk = T.PublicKey.fromSec1(&server_ks) catch
                                return s.writeError(.illegal_parameter);
                            const key_pair = @field(self.key_pairs, @tagName(t));
                            const mult = pk.p.mulPublic(key_pair.secret_key.bytes, .big) catch
                                return s.writeError(.illegal_parameter);
                            shared_key = &mult.affineCoordinates().x.toBytes(.big);
                        },
                        // Server sent us back unknown key. That's weird because we only request known ones,
                        // but we can keep iterating for another.
                        else => {
                            try r.skipBytes(key_size, .{});
                        },
                    }
                },
                else => {
                    try r.skipBytes(ext.len, .{});
                },
            }
        }

        if (supported_version != tls.Version.tls_1_3) return s.writeError(.protocol_version);
        if (shared_key == null) return s.writeError(.missing_extension);

        s.transcript_hash.?.setActive(cipher_suite);
        const hello_hash = s.transcript_hash.?.peek();

        const handshake_cipher = tls.HandshakeCipher.init(
            cipher_suite,
            shared_key.?,
            hello_hash,
            self.logger(),
        ) catch return s.writeError(.illegal_parameter);
        s.cipher = .{ .handshake = handshake_cipher };
    }

    pub fn recv_encrypted_extensions(self: *Handshake) !void {
        var s = &self.tls_stream;
        var r = s.stream().reader();

        var iter = try s.extensions();
        while (try iter.next()) |ext| {
            try r.skipBytes(ext.len, .{});
        }
    }

    /// Verifies trust chain if `options.ca_bundle` is specified.
    ///
    /// Caller owns allocated Certificate.Parsed.certificate.
    pub fn recv_certificate(self: *Handshake) !Certificate.Parsed {
        var s = &self.tls_stream;
        var r = s.stream().reader();
        const allocator = self.options.allocator;
        const ca_bundle = self.options.ca_bundle;
        const verify = ca_bundle != null;

        var context: [tls.Certificate.max_context_len]u8 = undefined;
        const context_len = try s.read(u8);
        if (context_len > tls.Certificate.max_context_len) return s.writeError(.decode_error);
        try r.readNoEof(context[0..context_len]);

        var first: ?crypto.Certificate.Parsed = null;
        errdefer if (first) |f| allocator.free(f.certificate.buffer);
        var prev: Certificate.Parsed = undefined;
        var verified = false;
        const now_sec = std.time.timestamp();

        var certs_iter = try s.iterator(u24, u24);
        while (try certs_iter.next()) |cert_len| {
            const is_first = first == null;

            if (verified) {
                try r.skipBytes(cert_len, .{});
            } else {
                if (cert_len > tls.Certificate.Entry.max_data_len)
                    return s.writeError(.decode_error);
                const buf = allocator.alloc(u8, cert_len) catch
                    return s.writeError(.internal_error);
                defer if (!is_first) allocator.free(buf);
                errdefer allocator.free(buf);
                try r.readNoEof(buf);

                const cert = crypto.Certificate{ .buffer = buf, .index = 0 };
                const cur = cert.parse() catch return s.writeError(.bad_certificate);
                if (first == null) {
                    if (verify) try cur.verifyHostName(self.options.host);
                    first = cur;
                } else {
                    if (verify) try prev.verify(cur, now_sec);
                }

                if (ca_bundle) |b| {
                    if (b.verify(cur, now_sec)) |_| {
                        verified = true;
                    } else |err| switch (err) {
                        error.CertificateIssuerNotFound => {},
                        error.CertificateExpired => return s.writeError(.certificate_expired),
                        else => return s.writeError(.bad_certificate),
                    }
                }

                prev = cur;
            }

            var ext_iter = try s.extensions();
            while (try ext_iter.next()) |ext| try r.skipBytes(ext.len, .{});
        }
        if (verify and !verified) return s.writeError(.bad_certificate);

        return if (first) |f| f else s.writeError(.bad_certificate);
    }

    pub fn recv_certificate_verify(self: *Handshake, digest: []const u8) !void {
        var s = &self.tls_stream;
        var r = s.stream().reader();
        const allocator = self.options.allocator;
        const cert = self.cert;

        const sig_content = tls.sigContent(digest);

        const scheme = try s.read(tls.SignatureScheme);
        const len = try s.read(u16);
        if (len > tls.CertificateVerify.max_signature_length)
            return s.writeError(.decode_error);
        const sig_bytes = allocator.alloc(u8, len) catch
            return s.writeError(.internal_error);
        defer allocator.free(sig_bytes);
        try r.readNoEof(sig_bytes);

        switch (scheme) {
            inline .ecdsa_secp256r1_sha256,
            .ecdsa_secp384r1_sha384,
            => |comptime_scheme| {
                if (cert.pub_key_algo != .X9_62_id_ecPublicKey)
                    return s.writeError(.bad_certificate);
                const Ecdsa = comptime_scheme.Ecdsa();
                const sig = Ecdsa.Signature.fromDer(sig_bytes) catch
                    return s.writeError(.decode_error);
                const key = Ecdsa.PublicKey.fromSec1(cert.pubKey()) catch
                    return s.writeError(.decode_error);
                sig.verify(sig_content, key) catch return s.writeError(.bad_certificate);
            },
            inline .rsa_pss_rsae_sha256,
            .rsa_pss_rsae_sha384,
            .rsa_pss_rsae_sha512,
            => |comptime_scheme| {
                if (cert.pub_key_algo != .rsaEncryption)
                    return s.writeError(.bad_certificate);

                const Hash = comptime_scheme.Hash();
                const rsa = Certificate.rsa;
                const key = rsa.PublicKey.fromDer(cert.pubKey()) catch
                    return s.writeError(.bad_certificate);
                switch (key.n.bits() / 8) {
                    inline 128, 256, 512 => |modulus_len| {
                        const sig = rsa.PSSSignature.fromBytes(modulus_len, sig_bytes);
                        rsa.PSSSignature.verify(modulus_len, sig, sig_content, key, Hash) catch
                            return s.writeError(.decode_error);
                    },
                    else => {
                        return s.writeError(.bad_certificate);
                    },
                }
            },
            inline .ed25519 => |comptime_scheme| {
                if (cert.pub_key_algo != .curveEd25519)
                    return s.writeError(.bad_certificate);
                const Eddsa = comptime_scheme.Eddsa();
                if (sig_content.len != Eddsa.Signature.encoded_length)
                    return s.writeError(.decode_error);
                const sig = Eddsa.Signature.fromBytes(sig_bytes[0..Eddsa.Signature.encoded_length].*);
                if (cert.pubKey().len != Eddsa.PublicKey.encoded_length)
                    return s.writeError(.decode_error);
                const key = Eddsa.PublicKey.fromBytes(cert.pubKey()[0..Eddsa.PublicKey.encoded_length].*) catch
                    return s.writeError(.bad_certificate);
                sig.verify(sig_content, key) catch return s.writeError(.bad_certificate);
            },
            else => {
                return s.writeError(.bad_certificate);
            },
        }
    }

    pub fn recv_finished(self: *Handshake, digest: []const u8) !void {
        var s = &self.tls_stream;
        var r = s.stream().reader();
        const cipher = s.cipher.handshake;

        switch (cipher) {
            inline else => |p| {
                const P = @TypeOf(p);
                const expected = &tls.hmac(P.Hmac, digest, p.server_finished_key);

                var actual: [expected.len]u8 = undefined;
                try r.readNoEof(&actual);
                if (!mem.eql(u8, expected, &actual)) return s.writeError(.decode_error);
            },
        }
    }

    pub fn send_finished(self: *Handshake) !void {
        var s = &self.tls_stream;

        const handshake_hash = s.transcript_hash.?.peek();

        const verify_data = switch (s.cipher.handshake) {
            inline .aes_128_gcm_sha256,
            .aes_256_gcm_sha384,
            .chacha20_poly1305_sha256,
            .aegis_256_sha512,
            .aegis_128l_sha256,
            => |v| brk: {
                const T = @TypeOf(v);
                const secret = v.client_finished_key;
                const transcript_hash = s.transcript_hash.?.peek();

                break :brk &tls.hmac(T.Hmac, transcript_hash, secret);
            },
            else => return s.writeError(.decrypt_error),
        };
        s.content_type = .handshake;
        _ = try s.write(tls.Handshake, .{ .finished = verify_data });
        try s.flush();

        const application_cipher = tls.ApplicationCipher.init(
            s.cipher.handshake,
            handshake_hash,
            self.logger(),
        );
        s.cipher = .{ .application = application_cipher };
        s.content_type = .application_data;
        s.transcript_hash = null;
    }

    fn logger(self: *Handshake) tls.KeyLogger {
        return tls.KeyLogger{
            .client_random = self.client_random,
            .writer = self.options.key_log,
        };
    }
};

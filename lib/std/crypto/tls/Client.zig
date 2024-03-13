const std = @import("../../std.zig");
const tls = std.crypto.tls;
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;

/// `StreamType` must conform to `tls.StreamInterface`.
pub fn Client(comptime StreamType: type) type {
    return struct {
        stream: Stream,
        options: Options,

        const Stream = tls.Stream(tls.Plaintext.max_length, StreamType);
        const Self = @This();

        /// Initiates a TLS handshake and establishes a TLSv1.3 session
        pub fn init(stream: *StreamType, options: Options) !Self {
            const stream_ = tls.Stream(tls.Plaintext.max_length, StreamType){
                .stream = stream,
                .is_client = true,
            };
            var res = Self{ .stream = stream_, .options = options };

            var state = Command{ .send_hello = KeyPairs.init() };
            while (state != .sent_finished) state = try res.advance(state);

            return res;
        }

        /// Execute command and return next one.
        pub fn advance(self: *Self, command: Command) !Command {
            var stream = &self.stream;
            switch (command) {
                .send_hello => |key_pairs| {
                    try self.send_hello(key_pairs);

                    return .{ .recv_hello = key_pairs };
                },
                .recv_hello => |key_pairs| {
                    try stream.expectInnerPlaintext(.handshake, .server_hello);
                    try self.recv_hello(key_pairs);

                    return .{ .recv_encrypted_extensions = {} };
                },
                .recv_encrypted_extensions => {
                    try stream.expectInnerPlaintext(.handshake, .encrypted_extensions);
                    try self.recv_encrypted_extensions();

                    return .{ .recv_certificate_or_finished = {} };
                },
                .recv_certificate_or_finished => {
                    const digest = stream.transcript_hash.peek();
                    const inner_plaintext = try stream.readInnerPlaintext();
                    if (inner_plaintext.type != .handshake) return stream.writeError(.unexpected_message);
                    switch (inner_plaintext.handshake_type) {
                        .certificate => {
                            const parsed = try self.recv_certificate();

                            return .{ .recv_certificate_verify = parsed };
                        },
                        .finished => {
                            if (self.options.ca_bundle != null)
                                return self.stream.writeError(.certificate_required);

                            try self.recv_finished(digest);

                            return .{ .send_finished = {} };
                        },
                        else => return self.stream.writeError(.unexpected_message),
                    }
                },
                .recv_certificate_verify => |parsed| {
                    defer self.options.allocator.free(parsed.certificate.buffer);

                    const digest = stream.transcript_hash.peek();
                    try stream.expectInnerPlaintext(.handshake, .certificate_verify);
                    try self.recv_certificate_verify(digest, parsed);

                    return .{ .recv_finished = {} };
                },
                .recv_finished => {
                    const digest = stream.transcript_hash.peek();
                    try stream.expectInnerPlaintext(.handshake, .finished);
                    try self.recv_finished(digest);

                    return .{ .send_finished = {} };
                },
                .send_finished => {
                    try self.send_finished();

                    return .{ .sent_finished = {} };
                },
                .sent_finished => return .{ .sent_finished = {} },
            }
        }

        pub fn send_hello(self: *Self, key_pairs: KeyPairs) !void {
            const hello = tls.ClientHello{
                .random = key_pairs.hello_rand,
                .session_id = &key_pairs.session_id,
                .cipher_suites = self.options.cipher_suites,
                .extensions = &.{
                    .{ .server_name = &[_]tls.ServerName{.{ .host_name = self.options.host }} },
                    .{ .ec_point_formats = &[_]tls.EcPointFormat{.uncompressed} },
                    .{ .supported_groups = &tls.supported_groups },
                    .{ .signature_algorithms = &tls.supported_signature_schemes },
                    .{ .supported_versions = &[_]tls.Version{.tls_1_3} },
                    .{ .key_share = &[_]tls.KeyShare{
                        .{ .x25519_kyber768d00 = .{
                            .x25519 = key_pairs.x25519.public_key,
                            .kyber768d00 = key_pairs.kyber768d00.public_key,
                        } },
                        .{ .secp256r1 = key_pairs.secp256r1.public_key },
                        .{ .x25519 = key_pairs.x25519.public_key },
                    } },
                },
            };

            _ = try self.stream.write(tls.Handshake, .{ .client_hello = hello });
            try self.stream.flush();
        }

        pub fn recv_hello(self: *Self, key_pairs: KeyPairs) !void {
            var stream = &self.stream;
            var reader = stream.reader();

            // > The value of TLSPlaintext.legacy_record_version MUST be ignored by all implementations.
            _ = try stream.read(tls.Version);
            var random: [32]u8 = undefined;
            try reader.readNoEof(&random);
            if (mem.eql(u8, &random, &tls.ServerHello.hello_retry_request)) {
                // We already offered all our supported options and we aren't changing them.
                return stream.writeError(.unexpected_message);
            }

            var session_id_buf: [tls.ClientHello.session_id_max_len]u8 = undefined;
            const session_id_len = try stream.read(u8);
            if (session_id_len > tls.ClientHello.session_id_max_len)
                return stream.writeError(.illegal_parameter);
            const session_id: []u8 = session_id_buf[0..session_id_len];
            try reader.readNoEof(session_id);
            if (!mem.eql(u8, session_id, &key_pairs.session_id))
                return stream.writeError(.illegal_parameter);

            const cipher_suite = try stream.read(tls.CipherSuite);
            const compression_method = try stream.read(u8);
            if (compression_method != 0) return stream.writeError(.illegal_parameter);

            var supported_version: ?tls.Version = null;
            var shared_key: ?[]const u8 = null;

            var iter = try stream.extensions();
            while (try iter.next()) |ext| {
                switch (ext.type) {
                    .supported_versions => {
                        if (supported_version != null) return stream.writeError(.illegal_parameter);
                        supported_version = try stream.read(tls.Version);
                    },
                    .key_share => {
                        if (shared_key != null) return stream.writeError(.illegal_parameter);
                        const named_group = try stream.read(tls.NamedGroup);
                        const key_size = try stream.read(u16);
                        switch (named_group) {
                            .x25519_kyber768d00 => {
                                const T = tls.NamedGroupT(.x25519_kyber768d00);
                                const x25519_len = T.X25519.public_length;
                                const expected_len = x25519_len + T.Kyber768.ciphertext_length;
                                if (key_size != expected_len) return stream.writeError(.illegal_parameter);
                                var server_ks: [expected_len]u8 = undefined;
                                try reader.readNoEof(&server_ks);

                                const mult = T.X25519.scalarmult(
                                    key_pairs.x25519.secret_key,
                                    server_ks[0..x25519_len].*,
                                ) catch return stream.writeError(.decrypt_error);
                                const decaps = key_pairs.kyber768d00.secret_key.decaps(
                                    server_ks[x25519_len..expected_len],
                                ) catch return stream.writeError(.decrypt_error);
                                shared_key = &(mult ++ decaps);
                            },
                            .x25519 => {
                                const T = tls.NamedGroupT(.x25519);
                                const expected_len = T.public_length;
                                if (key_size != expected_len) return stream.writeError(.illegal_parameter);
                                var server_ks: [expected_len]u8 = undefined;
                                try reader.readNoEof(&server_ks);

                                const mult = crypto.dh.X25519.scalarmult(
                                    key_pairs.x25519.secret_key,
                                    server_ks[0..expected_len].*,
                                ) catch return stream.writeError(.illegal_parameter);
                                shared_key = &mult;
                            },
                            inline .secp256r1, .secp384r1 => |t| {
                                const T = tls.NamedGroupT(t);
                                const expected_len = T.PublicKey.uncompressed_sec1_encoded_length;
                                if (key_size != expected_len) return stream.writeError(.illegal_parameter);

                                var server_ks: [expected_len]u8 = undefined;
                                try reader.readNoEof(&server_ks);

                                const pk = T.PublicKey.fromSec1(&server_ks) catch
                                    return stream.writeError(.illegal_parameter);
                                const key_pair = @field(key_pairs, @tagName(t));
                                const mult = pk.p.mulPublic(key_pair.secret_key.bytes, .big) catch
                                    return stream.writeError(.illegal_parameter);
                                shared_key = &mult.affineCoordinates().x.toBytes(.big);
                            },
                            // Server sent us back unknown key. That's weird because we only request known ones,
                            // but we can try for another.
                            else => {
                                try reader.skipBytes(key_size, .{});
                            },
                        }
                    },
                    else => {
                        try reader.skipBytes(ext.len, .{});
                    },
                }
            }

            if (supported_version != tls.Version.tls_1_3) return stream.writeError(.protocol_version);
            if (shared_key == null) return stream.writeError(.missing_extension);

            stream.transcript_hash.setActive(cipher_suite);
            const hello_hash = stream.transcript_hash.peek();
            stream.handshake_cipher = tls.HandshakeCipher.init(cipher_suite, shared_key.?, hello_hash) catch return stream.writeError(.illegal_parameter);
        }

        pub fn recv_encrypted_extensions(self: *Self) !void {
            var stream = &self.stream;
            var reader = stream.reader();

            var iter = try stream.extensions();
            while (try iter.next()) |ext| {
                switch (ext.type) {
                    .server_name => {
                        try reader.skipBytes(ext.len, .{});
                    },
                    else => |t| {
                        std.debug.print("unsupported extension {}\n", .{t});
                        return stream.writeError(.unsupported_extension);
                    },
                }
            }
        }

        /// Verifies trust chain if `options.ca_bundle` is specified.
        ///
        /// Caller owns allocated Certificate.Parsed.certificate.
        pub fn recv_certificate(self: *Self) !Certificate.Parsed {
            var stream = &self.stream;
            var reader = stream.reader();
            const allocator = self.options.allocator;
            const ca_bundle = self.options.ca_bundle;
            const verify = ca_bundle != null;

            var context: [tls.Certificate.max_context_len]u8 = undefined;
            const context_len = try stream.read(u8);
            if (context_len > tls.Certificate.max_context_len) return stream.writeError(.decode_error);
            try reader.readNoEof(context[0..context_len]);

            var first: ?crypto.Certificate.Parsed = null;
            var prev: Certificate.Parsed = undefined;
            var verified = false;
            const now_sec = std.time.timestamp();

            var certs_iter = try stream.iterator(u24, u24);
            while (try certs_iter.next()) |cert_len| {
                const is_first = first == null;

                if (!verified) {
                    if (cert_len > tls.Certificate.Entry.max_data_len)
                        return stream.writeError(.decode_error);
                    const buf = allocator.alloc(u8, cert_len) catch
                        return stream.writeError(.internal_error);
                    defer if (!is_first) allocator.free(buf);
                    errdefer allocator.free(buf);
                    try reader.readNoEof(buf);

                    const cert = crypto.Certificate{ .buffer = buf, .index = 0 };
                    const cur = cert.parse() catch return stream.writeError(.bad_certificate);
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
                            error.CertificateExpired => return stream.writeError(.certificate_expired),
                            else => return stream.writeError(.bad_certificate),
                        }
                    }

                    prev = cur;
                }

                var ext_iter = try stream.extensions();
                while (try ext_iter.next()) |ext| try reader.skipBytes(ext.len, .{});
            }
            if (verify and !verified) return stream.writeError(.bad_certificate);

            return if (first) |r| r else stream.writeError(.bad_certificate);
        }

        pub fn recv_certificate_verify(self: *Self, digest: []const u8, cert: Certificate.Parsed) !void {
            var stream = &self.stream;
            var reader = stream.reader();
            const allocator = self.options.allocator;

            const sig_content = tls.sigContent(digest);

            const scheme = try stream.read(tls.SignatureScheme);
            const len = try stream.read(u16);
            if (len > tls.CertificateVerify.max_signature_length)
                return stream.writeError(.decode_error);
            const sig_bytes = allocator.alloc(u8, len) catch
                return stream.writeError(.internal_error);
            defer allocator.free(sig_bytes);
            try reader.readNoEof(sig_bytes);

            switch (scheme) {
                inline .ecdsa_secp256r1_sha256,
                .ecdsa_secp384r1_sha384,
                => |comptime_scheme| {
                    if (cert.pub_key_algo != .X9_62_id_ecPublicKey)
                        return stream.writeError(.bad_certificate);
                    const Ecdsa = SchemeEcdsa(comptime_scheme);
                    const sig = Ecdsa.Signature.fromDer(sig_bytes) catch
                        return stream.writeError(.decode_error);
                    const key = Ecdsa.PublicKey.fromSec1(cert.pubKey()) catch
                        return stream.writeError(.decode_error);
                    sig.verify(sig_content, key) catch return stream.writeError(.bad_certificate);
                },
                inline .rsa_pss_rsae_sha256,
                .rsa_pss_rsae_sha384,
                .rsa_pss_rsae_sha512,
                => |comptime_scheme| {
                    if (cert.pub_key_algo != .rsaEncryption)
                        return stream.writeError(.bad_certificate);

                    const Hash = SchemeHash(comptime_scheme);
                    const rsa = Certificate.rsa;
                    const components = rsa.PublicKey.parseDer(cert.pubKey()) catch
                        return stream.writeError(.decode_error);
                    const exponent = components.exponent;
                    const modulus = components.modulus;
                    switch (modulus.len) {
                        inline 128, 256, 512 => |modulus_len| {
                            const key = rsa.PublicKey.fromBytes(exponent, modulus) catch
                                return stream.writeError(.bad_certificate);
                            const sig = rsa.PSSSignature.fromBytes(modulus_len, sig_bytes);
                            rsa.PSSSignature.verify(modulus_len, sig, sig_content, key, Hash) catch
                                return stream.writeError(.decode_error);
                        },
                        else => {
                            return error.TlsBadRsaSignatureBitCount;
                        },
                    }
                },
                inline .ed25519 => |comptime_scheme| {
                    if (cert.pub_key_algo != .curveEd25519)
                        return stream.writeError(.bad_certificate);
                    const Eddsa = SchemeEddsa(comptime_scheme);
                    if (sig_content.len != Eddsa.Signature.encoded_length)
                        return stream.writeError(.decode_error);
                    const sig = Eddsa.Signature.fromBytes(sig_bytes[0..Eddsa.Signature.encoded_length].*);
                    if (cert.pubKey().len != Eddsa.PublicKey.encoded_length)
                        return stream.writeError(.decode_error);
                    const key = Eddsa.PublicKey.fromBytes(cert.pubKey()[0..Eddsa.PublicKey.encoded_length].*) catch
                        return stream.writeError(.bad_certificate);
                    sig.verify(sig_content, key) catch return stream.writeError(.bad_certificate);
                },
                else => {
                    return error.TlsBadSignatureScheme;
                },
            }
        }

        pub fn recv_finished(self: *Self, digest: []const u8) !void {
            var stream = &self.stream;
            var reader = stream.reader();
            const cipher = stream.handshake_cipher.?;

            switch (cipher) {
                .empty_renegotiation_info_scsv => return stream.writeError(.decode_error),
                inline else => |p| {
                    const P = @TypeOf(p);
                    const expected = &tls.hmac(P.Hmac, digest, p.server_finished_key);

                    var actual: [expected.len]u8 = undefined;
                    try reader.readNoEof(&actual);
                    if (!mem.eql(u8, expected, &actual)) return stream.writeError(.decode_error);
                },
            }

            stream.application_cipher = tls.ApplicationCipher.init(
                stream.handshake_cipher.?,
                stream.transcript_hash.peek(),
            );
        }

        pub fn send_finished(self: *Self) !void {
            var stream = &self.stream;

            stream.version = .tls_1_2;
            stream.content_type = .change_cipher_spec;
            _ = try stream.write(tls.ChangeCipherSpec, .change_cipher_spec);
            try stream.flush();

            const verify_data = switch (stream.handshake_cipher.?) {
                inline .aes_128_gcm_sha256,
                .aes_256_gcm_sha384,
                .chacha20_poly1305_sha256,
                .aegis_256_sha512,
                .aegis_128l_sha256,
                => |v| brk: {
                    const T = @TypeOf(v);
                    const secret = v.client_finished_key;
                    const transcript_hash = stream.transcript_hash.peek();

                    break :brk &tls.hmac(T.Hmac, transcript_hash, secret);
                },
                else => return stream.writeError(.decrypt_error),
            };
            stream.content_type = .handshake;
            _ = try stream.write(tls.Handshake, .{ .finished = verify_data });
            try stream.flush();

            stream.content_type = .application_data;
        }
    };
}

pub const Options = struct {
    /// Trusted certificate authority bundle used to authenticate server certificates.
    /// When null, server certificate and certificate_verify messages will be skipped.
    ca_bundle: ?Certificate.Bundle,
    /// Used to verify cerficate chain and for Server Name Indication.
    host: []const u8,
    /// List of cipher suites to advertise in order of descending preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    /// By default, reaching the end-of-stream when reading from the server will
    /// cause `error.TlsConnectionTruncated` to be returned, unless a close_notify
    /// message has been received. By setting this flag to `true`, instead, the
    /// end-of-stream will be forwarded to the application layer above TLS.
    /// This makes the application vulnerable to truncation attacks unless the
    /// application layer itself verifies that the amount of data received equals
    /// the amount of data expected, such as HTTP with the Content-Length header.
    allow_truncation_attacks: bool = false,
    /// Certificate messages may be up to 2^24-1 bytes long.
    /// Certificate verify messages may be up to 2^16-1 bytes long.
    /// This is the allocator used for them.
    allocator: std.mem.Allocator,
};

/// One of these potential key pairs will be selected during the handshake.
pub const KeyPairs = struct {
    hello_rand: [hello_rand_length]u8,
    session_id: [session_id_length]u8,
    kyber768d00: Kyber768,
    secp256r1: Secp256r1,
    secp384r1: Secp384r1,
    x25519: X25519,

    const Self = @This();

    const hello_rand_length = 32;
    const session_id_length = 32;
    const X25519 = tls.NamedGroupT(.x25519).KeyPair;
    const Secp256r1 = tls.NamedGroupT(.secp256r1).KeyPair;
    const Secp384r1 = tls.NamedGroupT(.secp384r1).KeyPair;
    const Kyber768 = tls.NamedGroupT(.x25519_kyber768d00).Kyber768.KeyPair;

    pub fn init() Self {
        var random_buffer: [
            hello_rand_length +
                session_id_length +
                Kyber768.seed_length +
                Secp256r1.seed_length +
                Secp384r1.seed_length +
                X25519.seed_length
        ]u8 = undefined;

        while (true) {
            crypto.random.bytes(&random_buffer);

            const split1 = hello_rand_length;
            const split2 = split1 + session_id_length;
            const split3 = split2 + Kyber768.seed_length;
            const split4 = split3 + Secp256r1.seed_length;
            const split5 = split4 + Secp384r1.seed_length;

            return initAdvanced(
                random_buffer[0..split1].*,
                random_buffer[split1..split2].*,
                random_buffer[split2..split3].*,
                random_buffer[split3..split4].*,
                random_buffer[split4..split5].*,
                random_buffer[split5..].*,
            ) catch continue;
        }
    }

    pub fn initAdvanced(
        hello_rand: [hello_rand_length]u8,
        session_id: [session_id_length]u8,
        kyber_768_seed: [Kyber768.seed_length]u8,
        secp256r1_seed: [Secp256r1.seed_length]u8,
        secp384r1_seed: [Secp384r1.seed_length]u8,
        x25519_seed: [X25519.seed_length]u8,
    ) !Self {
        return Self{
            .kyber768d00 = Kyber768.create(kyber_768_seed) catch {},
            .secp256r1 = Secp256r1.create(secp256r1_seed) catch |err| switch (err) {
                error.IdentityElement => return error.InsufficientEntropy, // Private key is all zeroes.
            },
            .secp384r1 = Secp384r1.create(secp384r1_seed) catch |err| switch (err) {
                error.IdentityElement => return error.InsufficientEntropy, // Private key is all zeroes.
            },
            .x25519 = X25519.create(x25519_seed) catch |err| switch (err) {
                error.IdentityElement => return error.InsufficientEntropy, // Private key is all zeroes.
            },
            .hello_rand = hello_rand,
            .session_id = session_id,
        };
    }
};

fn SchemeEcdsa(comptime scheme: tls.SignatureScheme) type {
    return switch (scheme) {
        .ecdsa_secp256r1_sha256 => crypto.sign.ecdsa.EcdsaP256Sha256,
        .ecdsa_secp384r1_sha384 => crypto.sign.ecdsa.EcdsaP384Sha384,
        else => @compileError("bad scheme"),
    };
}

fn SchemeHash(comptime scheme: tls.SignatureScheme) type {
    return switch (scheme) {
        .rsa_pss_rsae_sha256 => crypto.hash.sha2.Sha256,
        .rsa_pss_rsae_sha384 => crypto.hash.sha2.Sha384,
        .rsa_pss_rsae_sha512 => crypto.hash.sha2.Sha512,
        else => @compileError("bad scheme"),
    };
}

fn SchemeEddsa(comptime scheme: tls.SignatureScheme) type {
    return switch (scheme) {
        .ed25519 => crypto.sign.Ed25519,
        else => @compileError("bad scheme"),
    };
}

/// A single `send` or `recv`. Allows for testing `advance`.
pub const Command = union(enum) {
    send_hello: KeyPairs,
    recv_hello: KeyPairs,
    recv_encrypted_extensions: void,
    recv_certificate_or_finished: void,
    recv_certificate_verify: Certificate.Parsed,
    recv_finished: void,
    send_finished: void,
    sent_finished: void,
};

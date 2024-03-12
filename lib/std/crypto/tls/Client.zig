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
        stream: tls.Stream(tls.Plaintext.max_length, StreamType),
        options: Options,

        const Self = @This();

        /// Initiates a TLS handshake and establishes a TLSv1.3 session
        pub fn init(stream: *StreamType, options: Options) !Self {
            var stream_ = tls.Stream(tls.Plaintext.max_length, StreamType){
                .stream = stream,
                .is_client = true,
            };
            var res = Self{ .stream = stream_, .options = options };
            {
                const key_pairs = try KeyPairs.init();
                try res.send_hello(key_pairs);
                try res.recv_hello(key_pairs);
            }
           _ =  &stream_;

            return res;
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
                            .x25119 = key_pairs.x25519.public_key,
                            .kyber768d00 = key_pairs.kyber768d00.public_key,
                        } },
                        .{ .secp256r1 = key_pairs.secp256r1.public_key },
                        .{ .x25519 = key_pairs.x25519.public_key },
                    } },
                },
            };

            try self.stream.write(tls.Handshake, .{ .client_hello = hello });
            try self.stream.flush();
        }

        pub fn recv_hello(self: *Self, key_pairs: KeyPairs) !void {
            try self.stream.expectFragment(.handshake, .server_hello);
            var reader = self.stream.reader();

            // > The value of TLSPlaintext.legacy_record_version MUST be ignored by all implementations.
            _ = try self.stream.read(tls.Version);
            var random: [32]u8 = undefined;
            try reader.readNoEof(&random);
            if (mem.eql(u8, &random, &tls.ServerHello.hello_retry_request)) {
                // We already offered all our supported options and we aren't changing them.
                return error.TlsUnexpectedMessage;
           }

            var session_id_buf: [tls.ClientHello.session_id_max_len]u8 = undefined;
            const session_id_len = try self.stream.read(u8);
            if (session_id_len > tls.ClientHello.session_id_max_len) return error.TlsUnexpectedMessage;
            const session_id: []u8 = session_id_buf[0..session_id_len];
            try reader.readNoEof(session_id);
            if (!mem.eql(u8, session_id, &key_pairs.session_id)) return error.TlsIllegalParameter;

            const cipher_suite = try self.stream.read(tls.CipherSuite);
            const compression_method = try self.stream.read(u8);
            if (compression_method != 0) return error.TlsIllegalParameter;

            var supported_version: ?tls.Version = null;
            var shared_key: ?[]const u8 = null;

            var iter = try self.stream.extensions();
            while (try iter.next()) |ext| {
                switch (ext.type) {
                    .supported_versions => {
                        if (supported_version != null) return error.TlsIllegalParameter;
                        supported_version = try self.stream.read(tls.Version);
                    },
                    .key_share => {
                        if (shared_key != null) return error.TlsIllegalParameter;
                        const named_group = try self.stream.read(tls.NamedGroup);
                        const key_size = try self.stream.read(u16);
                        switch (named_group) {
                            .x25519_kyber768d00 => {
                                const T = tls.NamedGroupT(.x25519_kyber768d00);
                                const x25519_len = T.X25519.public_length;
                                const expected_len = x25519_len + T.Kyber768.ciphertext_length;
                                if (key_size != expected_len)
                                    return error.TlsIllegalParameter;
                                var server_ks: [expected_len]u8 = undefined;
                                try reader.readNoEof(&server_ks);

                                shared_key = &((T.X25519.scalarmult(
                                    key_pairs.x25519.secret_key,
                                    server_ks[0..x25519_len].*,
                                ) catch return error.TlsDecryptFailure) ++ (key_pairs.kyber768d00.secret_key.decaps(
                                    server_ks[x25519_len..expected_len],
                                ) catch return error.TlsDecryptFailure));
                            },
                            .x25519 => {
                                const T = tls.NamedGroupT(.x25519);
                                const expected_len = T.public_length;
                                if (key_size != expected_len) return error.TlsIllegalParameter;
                                var server_ks: [expected_len]u8 = undefined;
                                try reader.readNoEof(&server_ks);

                                shared_key = &(crypto.dh.X25519.scalarmult(
                                    key_pairs.x25519.secret_key,
                                    server_ks[0..expected_len].*,
                                ) catch return error.TlsDecryptFailure);
                            },
                            inline .secp256r1, .secp384r1 => |t| {
                                const T = tls.NamedGroupT(t);
                                const expected_len = T.PublicKey.compressed_sec1_encoded_length;
                                if (key_size != expected_len) return error.TlsIllegalParameter;

                                var server_ks: [expected_len]u8 = undefined;
                                try reader.readNoEof(&server_ks);

                                const pk = T.PublicKey.fromSec1(&server_ks) catch {
                                    return error.TlsDecryptFailure;
                                };
                                const key_pair = @field(key_pairs, @tagName(t));
                                const mul = pk.p.mulPublic(key_pair.secret_key.bytes, .big) catch {
                                    return error.TlsDecryptFailure;
                                };
                                shared_key = &mul.affineCoordinates().x.toBytes(.big);
                            },
                            else => {
                                return error.TlsIllegalParameter;
                            },
                        }
                    },
                    else => {
                        try reader.skipBytes(ext.len, .{});
                    },
                }
            }

            if (supported_version != tls.Version.tls_1_3) return error.TlsIllegalParameter;
            if (shared_key == null) return error.TlsIllegalParameter;

            try self.stream.transcript_hash.setActive(cipher_suite);
            const hello_hash = self.stream.transcript_hash.peek();
            self.stream.handshake_cipher = try tls.HandshakeCipher.init(cipher_suite, shared_key.?, hello_hash);

            {
                try self.stream.expectFragment(.handshake, .encrypted_extensions);
                iter = try self.stream.extensions();
                while (try iter.next()) |ext|  {
                    try reader.skipBytes(ext.len, .{});
                }
            }

            // CertificateRequest*
            // Certificate*
            // CertificateVerify*
            {
                try self.stream.expectFragment(.handshake, .certificate);

                var context: [tls.Certificate.max_context_len]u8 = undefined;
                const context_len = try self.stream.read(u8);
                try reader.readNoEof(context[0..context_len]);

                var certs_iter = try self.stream.iterator(u24, u24);
                while (try certs_iter.next()) |cert_len| {
                    try reader.skipBytes(cert_len, .{});
                    var ext_iter = try self.stream.extensions();
                    while (try ext_iter.next()) |ext| {
                        switch (ext.type) {
                            else => {
                                try reader.skipBytes(ext.len, .{});
                            },
                        }
                    }
                }
            }

            {
                try self.stream.expectFragment(.handshake, .certificate_verify);

                const scheme = try self.stream.read(tls.SignatureScheme);
                const len = try self.stream.read(u16);
                try reader.skipBytes(len, .{});

                // TODO: verify
                _ = .{ scheme };
            }

            {
                try self.stream.expectFragment(.handshake, .finished);

                var verify_data: [48]u8 = undefined;
                try reader.readNoEof(&verify_data);

                // TODO: verify
                _ = .{ verify_data };
            }

            self.stream.application_cipher = tls.ApplicationCipher.init(
                self.stream.handshake_cipher.?,
                self.stream.transcript_hash.peek(),
            );
        }

        pub fn send_finished(self: *Self) !void {
            self.stream.version = .tls_1_2;
            self.stream.content_type = .change_cipher_spec;
            _ = try self.stream.write(tls.ChangeCipherSpec, .change_cipher_spec);
            try self.stream.flush();

            const verify_data = switch (self.stream.handshake_cipher.?) {
                inline
                    .aes_256_gcm_sha384,
                    => |v| brk: {
                        const T = @TypeOf(v);
                        const secret = v.client_finished_key;
                        const transcript_hash = self.stream.transcript_hash.peek();

                        break :brk tls.hmac(T.Hmac, transcript_hash, secret);
                    },
                else => return error.TlsDecryptFailure,
            };
            self.stream.content_type = .handshake;
            _ = try self.stream.write(tls.Handshake, .{ .finished = &verify_data });
            try self.stream.flush();

            self.stream.content_type = .application_data;
        }
    };
}

pub const Options = struct {
    /// Used to verify certificate chain. If null will **dangerously** skip certificate verification.
    ca_bundle: ?Certificate.Bundle,
    /// Used to verify cerficate chain and for Server Name Indication.
    host: []const u8,
    /// List of potential cipher suites in order of descending preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    /// By default, reaching the end-of-stream when reading from the server will
    /// cause `error.TlsConnectionTruncated` to be returned, unless a close_notify
    /// message has been received. By setting this flag to `true`, instead, the
    /// end-of-stream will be forwarded to the application layer above TLS.
    /// This makes the application vulnerable to truncation attacks unless the
    /// application layer itself verifies that the amount of data received equals
    /// the amount of data expected, such as HTTP with the Content-Length header.
    allow_truncation_attacks: bool = false,
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
            const split5 = split3 + Secp384r1.seed_length;

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

/// Abstraction for sending multiple byte buffers to a slice of iovecs.
const VecPut = struct {
    iovecs: []const std.os.iovec,
    idx: usize = 0,
    off: usize = 0,
    total: usize = 0,

    /// Returns the amount actually put which is always equal to bytes.len
    /// unless the vectors ran out of space.
    fn put(vp: *VecPut, bytes: []const u8) usize {
        if (vp.idx >= vp.iovecs.len) return 0;
        var bytes_i: usize = 0;
        while (true) {
            const v = vp.iovecs[vp.idx];
            const dest = v.iov_base[vp.off..v.iov_len];
            const src = bytes[bytes_i..][0..@min(dest.len, bytes.len - bytes_i)];
            @memcpy(dest[0..src.len], src);
            bytes_i += src.len;
            vp.off += src.len;
            if (vp.off >= v.iov_len) {
                vp.off = 0;
                vp.idx += 1;
                if (vp.idx >= vp.iovecs.len) {
                    vp.total += bytes_i;
                    return bytes_i;
                }
            }
            if (bytes_i >= bytes.len) {
                vp.total += bytes_i;
                return bytes_i;
            }
        }
    }

    /// Returns the next buffer that consecutive bytes can go into.
    fn peek(vp: VecPut) []u8 {
        if (vp.idx >= vp.iovecs.len) return &.{};
        const v = vp.iovecs[vp.idx];
        return v.iov_base[vp.off..v.iov_len];
    }

    // After writing to the result of peek(), one can call next() to
    // advance the cursor.
    fn next(vp: *VecPut, len: usize) void {
        vp.total += len;
        vp.off += len;
        if (vp.off >= vp.iovecs[vp.idx].iov_len) {
            vp.off = 0;
            vp.idx += 1;
        }
    }

    fn freeSize(vp: VecPut) usize {
        if (vp.idx >= vp.iovecs.len) return 0;
        var total: usize = 0;
        total += vp.iovecs[vp.idx].iov_len - vp.off;
        if (vp.idx + 1 >= vp.iovecs.len) return total;
        for (vp.iovecs[vp.idx + 1 ..]) |v| total += v.iov_len;
        return total;
    }
};

/// Limit iovecs to a specific byte size.
fn limitVecs(iovecs: []std.os.iovec, len: usize) []std.os.iovec {
    var bytes_left: usize = len;
    for (iovecs, 0..) |*iovec, vec_i| {
        if (bytes_left <= iovec.iov_len) {
            iovec.iov_len = bytes_left;
            return iovecs[0 .. vec_i + 1];
        }
        bytes_left -= iovec.iov_len;
    }
    return iovecs;
}

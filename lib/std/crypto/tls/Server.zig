const std = @import("../../std.zig");
const tls = std.crypto.tls;
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;

pub const TranscriptHash = std.crypto.hash.sha2.Sha384;

/// `StreamType` must conform to `tls.StreamInterface`.
pub fn Server(comptime StreamType: type) type {
    return struct {
        stream: tls.Stream(tls.Plaintext.max_length, StreamType, TranscriptHash),
        options: Options,

        const Self = @This();

        /// Initiates a TLS handshake and establishes a TLSv1.3 session
        pub fn init(stream: *StreamType, options: Options) !Self {
            var stream_ = tls.Stream(tls.Plaintext.max_length, StreamType, TranscriptHash){
                .stream = stream,
                .transcript_hash = TranscriptHash.init(.{}),
                .is_client = false,
            };
            var res = Self{ .stream = stream_, .options = options };
            const client_hello = try res.recv_hello(&stream_);
            _ = client_hello;
            // {
            // var random_buffer: [32]u8 = undefined;
            // crypto.random.bytes(&random_buffer);
            // const key_pair = crypto.dh.X25519.KeyPair.create(random_buffer) catch |err| switch (err) {
            //     error.IdentityElement => return error.InsufficientEntropy, // Private key is all zeroes.
            // };
            //     try res.send_hello(key_pair);
            // }

            return res;
        }

        /// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
        /// Returns the number of plaintext bytes sent, which may be fewer than `bytes.len`.
        pub fn write(self: *Self, bytes: []const u8) !usize {
            return self.writeEnd(bytes, false);
        }

        /// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
        pub fn writeAll(self: *Self, bytes: []const u8) !void {
            var index: usize = 0;
            while (index < bytes.len) {
                index += try self.write(bytes[index..]);
            }
        }

        /// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
        /// If `end` is true, then this function additionally sends a `close_notify` alert,
        /// which is necessary for the server to distinguish between a properly finished
        /// TLS session, or a truncation attack.
        pub fn writeAllEnd(self: *Self, bytes: []const u8, end: bool) !void {
            var index: usize = 0;
            while (index < bytes.len) {
                index += try self.writeEnd(bytes[index..], end);
            }
        }

        /// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
        /// Returns the number of plaintext bytes sent, which may be fewer than `bytes.len`.
        /// If `end` is true, then this function additionally sends a `close_notify` alert,
        /// which is necessary for the server to distinguish between a properly finished
        /// TLS session, or a truncation attack.
        pub fn writeEnd(self: *Self, bytes: []const u8, end: bool) !usize {
            try self.stream.writeAll(bytes);
            if (end) {
                const alert = tls.Alert{
                    .level = .fatal,
                    .description = .close_notify,
                };
                try self.stream.write(tls.Alert, alert);
                try self.stream.flush();
            }
            return bytes.len;
        }

        /// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
        /// Returns the number of bytes read, calling the underlying read function the
        /// minimal number of times until the buffer has at least `len` bytes filled.
        /// If the number read is less than `len` it means the stream reached the end.
        /// Reaching the end of the stream is not an error condition.
        pub fn readAtLeast(self: *Self, buffer: []u8, len: usize) !usize {
            var iovecs = [1]std.os.iovec{.{ .iov_base = buffer.ptr, .iov_len = buffer.len }};
            return self.readvAtLeast(&iovecs, len);
        }

        /// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
        pub fn read(self: *Self, buffer: []u8) !usize {
            return self.readAtLeast(buffer, 1);
        }

        /// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
        /// Returns the number of bytes read. If the number read is smaller than
        /// `buffer.len`, it means the stream reached the end. Reaching the end of the
        /// stream is not an error condition.
        pub fn readAll(self: *Self, buffer: []u8) !usize {
            return self.readAtLeast(buffer, buffer.len);
        }

        /// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
        /// Returns the number of bytes read. If the number read is less than the space
        /// provided it means the stream reached the end. Reaching the end of the
        /// stream is not an error condition.
        /// The `iovecs` parameter is mutable because this function needs to mutate the fields in
        /// order to handle partial reads from the underlying stream layer.
        pub fn readv(self: *Self, iovecs: []std.os.iovec) !usize {
            return self.readvAtLeast(iovecs, 1);
        }

        /// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
        /// Returns the number of bytes read, calling the underlying read function the
        /// minimal number of times until the iovecs have at least `len` bytes filled.
        /// If the number read is less than `len` it means the stream reached the end.
        /// Reaching the end of the stream is not an error condition.
        /// The `iovecs` parameter is mutable because this function needs to mutate the fields in
        /// order to handle partial reads from the underlying stream layer.
        pub fn readvAtLeast(self: *Self, iovecs: []std.os.iovec, len: usize) !usize {
            if (self.eof()) return 0;

            var off_i: usize = 0;
            var vec_i: usize = 0;
            while (true) {
                var amt = try self.readvAdvanced(iovecs[vec_i..]);
                off_i += amt;
                if (self.eof() or off_i >= len) return off_i;
                while (amt >= iovecs[vec_i].iov_len) {
                    amt -= iovecs[vec_i].iov_len;
                    vec_i += 1;
                }
                iovecs[vec_i].iov_base += amt;
                iovecs[vec_i].iov_len -= amt;
            }
        }

        /// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
        /// Returns number of bytes that have been read, populated inside `iovecs`. A
        /// return value of zero bytes does not mean end of stream. Instead, check the `eof()`
        /// for the end of stream. The `eof()` may be true after any call to
        /// `read`, including when greater than zero bytes are returned, and this
        /// function asserts that `eof()` is `false`.
        /// See `readv` for a higher level function that has the same, familiar API as
        /// other read functions, such as `std.fs.File.read`.
        pub fn readvAdvanced(self: *Self, iovecs: []const std.os.iovec) !usize {
            _ = .{ self, iovecs };
            return 0;
        }

        pub fn eof(self: *Self) bool {
            return self.stream.eof();
        }

        const ClientHello = struct {
            random: [32]u8,
            session_id: [32]u8,
            cipher_suite: tls.CipherSuite,
            key_share: tls.KeyShare,
        };

        pub fn recv_hello(self: *Self) !ClientHello {
            try self.stream.readFragment(.client_hello);

            // TODO: verify this
            const msg_len = try self.stream.read(u24);
            std.debug.print("msg_len {d}\n", .{msg_len});
            // > The value of TLSPlaintext.legacy_record_version MUST be ignored by all implementations.
            _ = try self.stream.read(tls.Version);
            const client_random = try self.stream.readAll(32);
            const session_id = try self.stream.readSmallArray(u8);
            if (session_id.len != 32) return error.TlsUnexpectedMessage;

            var selected_suite: ?tls.CipherSuite = null;

            var cipher_suite_iter = try self.stream.iterator(tls.CipherSuite);
            while (try cipher_suite_iter.next()) |suite| {
                if (selected_suite == null) brk: {
                    for (self.options.cipher_suites) |s| {
                        if (s == suite) {
                            selected_suite = s;
                            break :brk;
                        }
                    }
                }
            }

            if (selected_suite == null) return error.TlsUnexpectedMessage;

            const compression_methods = try self.stream.readAll(2);
            if (!std.mem.eql(u8, compression_methods, &[_]u8{ 1, 0 })) return error.TlsUnexpectedMessage;

            var tls_version: ?tls.Version = null;
            var key_share: ?tls.KeyShare = null;
            var ec_point_format: ?tls.EcPointFormat = null;

            var extension_iter = try self.stream.extensions();
            while (try extension_iter.next()) |ext| {
                switch (ext.type) {
                    .supported_versions => {
                        if (tls_version != null) return error.TlsUnexpectedMessage;
                        const versions = try self.stream.readSmallArray(tls.Version);
                        for (versions) |v| {
                            std.debug.print("version {}\n", .{v});
                            if (v == .tls_1_3) tls_version = v;
                        }
                    },
                    // TODO: use supported_groups instead
                    .key_share => {
                        if (key_share != null) return error.TlsUnexpectedMessage;

                        var key_share_iter = try self.stream.iterator(tls.KeyShare.Header);
                        while (try key_share_iter.next()) |ks| {
                            const key = try self.stream.readAll(ks.len);
                            if (ks.group == .x25519) {
                                key_share = .{ .x25519 = undefined };
                                if (ks.len != key_share.?.keyLen(true)) return error.TlsUnexpectedMessage;
                                @memcpy(&key_share.?.x25519, key);
                            }
                        }
                    },
                    .ec_point_formats => {
                        const formats = try self.stream.readSmallArray(tls.EcPointFormat);
                        for (formats) |f| {
                            if (f == .uncompressed) ec_point_format = .uncompressed;
                        }
                    },
                    else => {
                        _ = try self.stream.readAll(ext.len);
                    },
                }
            }

            if (tls_version == null) return error.TlsUnexpectedMessage;
            if (key_share == null) return error.TlsUnexpectedMessage;
            if (ec_point_format == null) return error.TlsUnexpectedMessage;

            return .{
                .random = client_random[0..32].*,
                .session_id = session_id[0..32].*,
                .cipher_suite = selected_suite.?,
                .key_share = key_share.?,
            };
        }

        /// `key_pair`'s active member MUST match `client_hello.key_share`
        pub fn send_hello(self: *Self, client_hello: ClientHello, key_pair: KeyPair) !void {
            const hello = tls.ServerHello{
                .random = key_pair.random,
                .session_id = &client_hello.session_id,
                .cipher_suite = client_hello.cipher_suite,
                .extensions = &.{
                    .{ .supported_versions = &[_]tls.Version{.tls_1_3} },
                    .{ .key_share = &[_]tls.KeyShare{key_pair.pair.toKeyShare()} },
                },
            };
            self.stream.version = .tls_1_2;
            try self.stream.write(tls.ServerHello, hello);
            try self.stream.flush();

            self.stream.content_type = .change_cipher_spec;
            try self.stream.write(tls.ChangeCipherSpec, .change_cipher_spec);
            try self.stream.flush();

            const shared_key = switch (client_hello.key_share) {
                .x25519_kyber768d00 => |ks| brk: {
                    const T = tls.NamedGroupT(.x25519_kyber768d00);
                    const pair: tls.X25519Kyber768Draft.KeyPair = key_pair.pair.x25519_kyber768d00;
                    const shared_point = T.X25519.scalarmult(
                        ks.x25519,
                        pair.x25519.secret_key,
                    ) catch return error.TlsDecryptFailure;
                    // pair.kyber768d00.secret_key
                    // ks.kyber768d00
                    const encaps = ks.kyber768d00.encaps(null).ciphertext;

                    break :brk &(shared_point ++ encaps);
                },
                .x25519 => |ks| brk: {
                    const shared_point = tls.NamedGroupT(.x25519).scalarmult(
                        key_pair.pair.x25519.secret_key,
                        ks,
                    ) catch return error.TlsDecryptFailure;
                    break :brk &shared_point;
                },
                .secp256r1 => |ks| brk: {
                    const mul = ks.p.mulPublic(
                        key_pair.pair.secp256r1.secret_key.bytes,
                        .big,
                    ) catch
                        return error.TlsDecryptFailure;
                    break :brk &mul.affineCoordinates().x.toBytes(.big);
                },
                else => return error.TlsIllegalParameter,
            };

            const hello_hash = self.stream.transcript_hash.peek();
            self.stream.handshake_cipher = tls.HandshakeCipher.init(client_hello.cipher_suite, shared_key, &hello_hash);
            self.stream.handshake_cipher.?.print();

            const extensions = tls.EncryptedExtensions{ .extensions = &.{} };
            self.stream.content_type = .handshake;
            try self.stream.write(tls.EncryptedExtensions, extensions);
            try self.stream.flush();

            try self.stream.write(tls.Certificate, self.options.certificate);
            try self.stream.flush();
        }
    };
}

pub const Options = struct {
    /// List of potential cipher suites in order of descending preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    certificate: tls.Certificate,
};

pub const KeyPair = struct {
    random: [32]u8,
    pair: tls.KeyPair,
};

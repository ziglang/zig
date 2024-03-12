const std = @import("../../std.zig");
const tls = std.crypto.tls;
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const io = std.io;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;
const Allocator = std.mem.Allocator;

/// `StreamType` must conform to `tls.StreamInterface`.
pub fn Server(comptime StreamType: type) type {
    return struct {
        stream: Stream,
        options: Options,
        /// Only used during handshake for messages larger than tls.Plaintext.max_length.
        // allocator: Allocator,

        const Stream = tls.Stream(tls.Plaintext.max_length, StreamType);
        const Self = @This();

        /// Initiates a TLS handshake and establishes a TLSv1.3 session
        pub fn init(stream: *StreamType, options: Options) !Self {
            var stream_ = tls.Stream(tls.Plaintext.max_length, StreamType){
                .stream = stream,
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

        const ClientHello = struct {
            random: [32]u8,
            session_id_len: u8,
            session_id: [32]u8,
            cipher_suite: tls.CipherSuite,
            key_share: tls.KeyShare,
            sig_scheme: ?tls.SignatureScheme,
        };

        pub fn recv_hello(self: *Self) !ClientHello {
            try self.stream.expectFragment(.handshake, .client_hello);
            var reader = self.stream.reader();

            _ = try self.stream.read(tls.Version);
            var client_random: [32]u8 = undefined;
            try reader.readNoEof(&client_random);

            var session_id: [tls.ClientHello.session_id_max_len]u8 = undefined;
            const session_id_len = try self.stream.read(u8);
            if (session_id_len > tls.ClientHello.session_id_max_len) return error.TlsUnexpectedMessage;
            try reader.readNoEof(session_id[0..session_id_len]);

            const cipher_suite: tls.CipherSuite = brk: {
                var cipher_suite_iter = try self.stream.iterator(u16, tls.CipherSuite);
                var res: ?tls.CipherSuite = null;
                while (try cipher_suite_iter.next()) |suite| {
                    for (self.options.cipher_suites) |s| {
                        if (s == suite and res == null) res = s;
                    }
                }
                if (res == null) return error.TlsUnexpectedMessage;
                break :brk res.?;
            };
            try self.stream.transcript_hash.setActive(cipher_suite);

            {
                var compression_methods: [2]u8 = undefined;
                try reader.readNoEof(&compression_methods);
                if (!std.mem.eql(u8, &compression_methods, &[_]u8{ 1, 0 })) return error.TlsUnexpectedMessage;
            }

            var tls_version: ?tls.Version = null;
            var key_share: ?tls.KeyShare = null;
            var ec_point_format: ?tls.EcPointFormat = null;
            var sig_scheme: ?tls.SignatureScheme = null;

            var extension_iter = try self.stream.extensions();
            while (try extension_iter.next()) |ext| {
                switch (ext.type) {
                    .supported_versions => {
                        if (tls_version != null) return error.TlsUnexpectedMessage;
                        var versions_iter = try self.stream.iterator(u8, tls.Version);
                        while (try versions_iter.next()) |v| {
                            if (v == .tls_1_3) tls_version = v;
                        }
                    },
                    // TODO: use supported_groups instead
                    .key_share => {
                        if (key_share != null) return error.TlsUnexpectedMessage;

                        var key_share_iter = try self.stream.iterator(u16, tls.KeyShare);
                        while (try key_share_iter.next()) |ks| {
                            switch (ks) {
                                .x25519 => key_share = ks,
                                else => {},
                            }
                        }
                    },
                    .ec_point_formats => {
                        var format_iter = try self.stream.iterator(u8, tls.EcPointFormat);
                        while (try format_iter.next()) |f| {
                            if (f == .uncompressed) ec_point_format = .uncompressed;
                        }
                    },
                    .signature_algorithms => {
                        var algos_iter = try self.stream.iterator(u16, tls.SignatureScheme);
                        while (try algos_iter.next()) |algo| {
                            if (algo == .rsa_pss_rsae_sha256) sig_scheme = algo;
                        }
                    },
                    else => {
                        try reader.skipBytes(ext.len, .{});
                    },
                }
            }

            if (tls_version == null) return error.TlsUnexpectedMessage;
            if (key_share == null) return error.TlsUnexpectedMessage;
            if (ec_point_format == null) return error.TlsUnexpectedMessage;

            return .{
                .random = client_random,
                .session_id_len = session_id_len,
                .session_id = session_id,
                .cipher_suite = cipher_suite,
                .key_share = key_share.?,
                .sig_scheme = sig_scheme,
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
            _ = try self.stream.write(tls.Handshake, .{ .server_hello = hello });
            try self.stream.flush();

            // > if the client sends a non-empty session ID, the server MUST send the change_cipher_spec
            if (hello.session_id.len > 0) {
                self.stream.content_type = .change_cipher_spec;
                _ = try self.stream.write(tls.ChangeCipherSpec, .change_cipher_spec);
                try self.stream.flush();
            }

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
            self.stream.handshake_cipher = try tls.HandshakeCipher.init(client_hello.cipher_suite, shared_key, hello_hash);

            self.stream.content_type = .handshake;
            _ = try self.stream.write(tls.Handshake, .{ .encrypted_extensions = &.{} });
            try self.stream.flush();

            _ = try self.stream.write(tls.Handshake, .{ .certificate = self.options.certificate });
            try self.stream.flush();

            // RFC 8446 S4.4.3
            // const signature_content = [_]u8{0x20} ** 64
            //     ++ "TLS 1.3, server CertificateVerify\x00".*
            //     ++ self.stream.transcript_hash.peek()
            //     ;

            // const cert = Certificate{ .buffer = self.options.certificate.entries[0].data, .index = 0 };
            // const parsed = try cert.parse();
            // const pub_key = parsed.pubKey();

            // switch (client_hello.sig_scheme) {
            //     .rsa_pss_rsae_sha256 => {
            //         const rsa = Certificate.rsa;
            //         const components = try rsa.PublicKey.parseDer(pub_key);
            //         const exponent = components.exponent;
            //         const modulus = components.modulus;
            //         switch (modulus.len) {
            //             inline 128, 256, 512 => |modulus_len| {
            //                 const key = try rsa.PublicKey.fromBytes(exponent, modulus);
            //                 const sig = rsa.PSSSignature.fromBytes(modulus_len, encoded_sig);
            //                 try rsa.PSSSignature.verify(modulus_len, sig, verify_bytes, key, Hash);
            //             },
            //             else => {
            //                 return error.TlsBadRsaSignatureBitCount;
            //             },
            //         }
            //     },
            //     else => {}
            // }
        }

        pub fn send_handshake_finish(self: *Self) !void {
            const verify_data = switch (self.stream.handshake_cipher.?) {
                inline
                    .aes_256_gcm_sha384,
                    => |v| brk: {
                        const T = @TypeOf(v);
                        const secret = v.server_finished_key;
                        const transcript_hash = self.stream.transcript_hash.peek();

                        break :brk tls.hmac(T.Hmac, transcript_hash, secret);
                    },
                else => return error.TlsDecryptFailure,
            };
            _ = try self.stream.write(tls.Handshake, .{ .finished =  &verify_data });
            try self.stream.flush();

            self.stream.application_cipher = tls.ApplicationCipher.init(
                self.stream.handshake_cipher.?,
                self.stream.transcript_hash.peek(),
            );
        }

        pub fn recv_finish(self: *Self) !void {
            try self.stream.expectFragment(.handshake, .finished);
            var reader = self.stream.reader();

            var verify_data: [48]u8 = undefined;
            try reader.readNoEof(&verify_data);

            // TODO: verify
            _ = .{ verify_data };
            self.stream.content_type = .application_data;
            self.stream.handshake_type = null;
        }
    };
}

pub const Options = struct {
    /// List of potential cipher suites in descending order of preference.
    cipher_suites: []const tls.CipherSuite = &tls.default_cipher_suites,
    certificate: tls.Certificate,
};

pub const KeyPair = struct {
    random: [32]u8,
    pair: tls.KeyPair,
};

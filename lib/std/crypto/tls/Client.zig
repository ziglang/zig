const std = @import("../../std.zig");
const tls = std.crypto.tls;
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;

pub const TranscriptHash = MultiHash;

/// `StreamType` must conform to `tls.StreamInterface`.
pub fn Client(comptime StreamType: type) type {
    return struct {
        stream: tls.Stream(tls.Plaintext.max_length, StreamType, TranscriptHash),
        options: Options,

        const Self = @This();

        /// Initiates a TLS handshake and establishes a TLSv1.3 session
        pub fn init(stream: *StreamType, options: Options) !Self {
            var stream_ = tls.Stream(tls.Plaintext.max_length, StreamType, TranscriptHash){
                .stream = stream,
                .transcript_hash = .{},
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

            // var cert_index: usize = 0;
            // var read_seq: u64 = 0;
            // var prev_cert: Certificate.Parsed = undefined;
            // // Set to true once a trust chain has been established from the first
            // // certificate to a root CA.
            // const HandshakeState = enum {
            //     /// In this state we expect an encrypted_extensions message.
            //     encrypted_extensions,
            //     /// In this state we expect certificate messages.
            //     certificate,
            //     /// In this state we expect certificate or certificate_verify messages.
            //     /// Certificate messages are ignored since the trust chain is already established.
            //     trust_chain_established,
            //     /// In this state, we expect only the finished message.
            //     finished,
            // };
            // var handshake_state: HandshakeState = .encrypted_extensions;
            // var cleartext_bufs: [2][tls.max_cipertext_inner_record_len]u8 = undefined;
            // var main_cert_pub_key_algo: Certificate.AlgorithmCategory = undefined;
            // var main_cert_pub_key_buf: [600]u8 = undefined;
            // var main_cert_pub_key_len: u16 = undefined;
            // const now_sec = std.time.timestamp();

            // const cleartext_buf = &cleartext_bufs[cert_index % 2];
            // const cleartext = try handshake_cipher.cleartext(record, read_seq, cleartext_buf);

            // const inner_ct: tls.ContentType = @enumFromInt(cleartext[cleartext.len - 1]);
            // if (inner_ct != .handshake) return error.TlsUnexpectedMessage;

            // var ctd = tls.Decoder.fromTheirSlice(cleartext[0 .. cleartext.len - 1]);
            // while (true) {
            //     try ctd.ensure(4);
            //     const handshake_type = ctd.decode(tls.HandshakeType);
            //     const handshake_len = ctd.decode(u24);
            //     var hsd = try ctd.sub(handshake_len);
            //     const wrapped_handshake = ctd.buf[ctd.idx - handshake_len - 4 .. ctd.idx];
            //     const handshake_buf = ctd.buf[ctd.idx - handshake_len .. ctd.idx];
            //     switch (handshake_type) {
            //         .encrypted_extensions => {
            //             if (handshake_state != .encrypted_extensions) return error.TlsUnexpectedMessage;
            //             handshake_state = .certificate;
            //             switch (handshake_cipher) {
            //                 inline else => |*p| p.transcript_hash.update(wrapped_handshake),
            //             }
            //             try hsd.ensure(2);
            //             const total_ext_size = hsd.decode(u16);
            //             var all_extd = try hsd.sub(total_ext_size);
            //             while (!all_extd.eof()) {
            //                 try all_extd.ensure(4);
            //                 const et = all_extd.decode(tls.ExtensionType);
            //                 const ext_size = all_extd.decode(u16);
            //                 const extd = try all_extd.sub(ext_size);
            //                 _ = extd;
            //                 switch (et) {
            //                     .server_name => {},
            //                     else => {},
            //                 }
            //             }
            //         },
            //         .certificate => cert: {
            //             switch (handshake_cipher) {
            //                 inline else => |*p| p.transcript_hash.update(wrapped_handshake),
            //             }
            //             switch (handshake_state) {
            //                 .certificate => {},
            //                 .trust_chain_established => break :cert,
            //                 else => return error.TlsUnexpectedMessage,
            //             }
            //             try hsd.ensure(1 + 4);
            //             const cert_req_ctx_len = hsd.decode(u8);
            //             if (cert_req_ctx_len != 0) return error.TlsIllegalParameter;
            //             const certs_size = hsd.decode(u24);
            //             var certs_decoder = try hsd.sub(certs_size);
            //             while (!certs_decoder.eof()) {
            //                 try certs_decoder.ensure(3);
            //                 const cert_size = certs_decoder.decode(u24);
            //                 const certd = try certs_decoder.sub(cert_size);

            //                 const subject_cert: Certificate = .{
            //                     .buffer = certd.buf,
            //                     .index = @intCast(certd.idx),
            //                 };
            //                 const subject = try subject_cert.parse();
            //                 if (cert_index == 0) {
            //                     // Verify the host on the first certificate.
            //                     try subject.verifyHostName(options.host);

            //                     // Keep track of the public key for the
            //                     // certificate_verify message later.
            //                     main_cert_pub_key_algo = subject.pub_key_algo;
            //                     const pub_key = subject.pubKey();
            //                     if (pub_key.len > main_cert_pub_key_buf.len)
            //                         return error.CertificatePublicKeyInvalid;
            //                     @memcpy(main_cert_pub_key_buf[0..pub_key.len], pub_key);
            //                     main_cert_pub_key_len = @intCast(pub_key.len);
            //                 } else {
            //                     try prev_cert.verify(subject, now_sec);
            //                 }

            //                 if (options.ca_bundle.verify(subject, now_sec)) |_| {
            //                     handshake_state = .trust_chain_established;
            //                     break :cert;
            //                 } else |err| switch (err) {
            //                     error.CertificateIssuerNotFound => {},
            //                     else => |e| return e,
            //                 }

            //                 prev_cert = subject;
            //                 cert_index += 1;

            //                 try certs_decoder.ensure(2);
            //                 const total_ext_size = certs_decoder.decode(u16);
            //                 const all_extd = try certs_decoder.sub(total_ext_size);
            //                 _ = all_extd;
            //             }
            //         },
            //         .certificate_verify => {
            //             switch (handshake_state) {
            //                 .trust_chain_established => handshake_state = .finished,
            //                 .certificate => return error.TlsCertificateNotVerified,
            //                 else => return error.TlsUnexpectedMessage,
            //             }

            //             try hsd.ensure(4);
            //             const scheme = hsd.decode(tls.SignatureScheme);
            //             const sig_len = hsd.decode(u16);
            //             try hsd.ensure(sig_len);
            //             const encoded_sig = hsd.slice(sig_len);
            //             const max_digest_len = 64;
            //             var verify_buffer: [64 + 34 + max_digest_len]u8 =
            //                 ([1]u8{0x20} ** 64) ++
            //                 "TLS 1.3, server CertificateVerify\x00".* ++
            //                 @as([max_digest_len]u8, undefined);

            //             const verify_bytes = switch (handshake_cipher) {
            //                 inline else => |*p| v: {
            //                     const transcript_digest = p.transcript_hash.peek();
            //                     verify_buffer[verify_buffer.len - max_digest_len ..][0..transcript_digest.len].* = transcript_digest;
            //                     p.transcript_hash.update(wrapped_handshake);
            //                     break :v verify_buffer[0 .. verify_buffer.len - max_digest_len + transcript_digest.len];
            //                 },
            //             };
            //             const main_cert_pub_key = main_cert_pub_key_buf[0..main_cert_pub_key_len];

            //             switch (scheme) {
            //                 inline .ecdsa_secp256r1_sha256,
            //                 .ecdsa_secp384r1_sha384,
            //                 => |comptime_scheme| {
            //                     if (main_cert_pub_key_algo != .X9_62_id_ecPublicKey)
            //                         return error.TlsBadSignatureScheme;
            //                     const Ecdsa = SchemeEcdsa(comptime_scheme);
            //                     const sig = try Ecdsa.Signature.fromDer(encoded_sig);
            //                     const key = try Ecdsa.PublicKey.fromSec1(main_cert_pub_key);
            //                     try sig.verify(verify_bytes, key);
            //                 },
            //                 inline .rsa_pss_rsae_sha256,
            //                 .rsa_pss_rsae_sha384,
            //                 .rsa_pss_rsae_sha512,
            //                 => |comptime_scheme| {
            //                     if (main_cert_pub_key_algo != .rsaEncryption)
            //                         return error.TlsBadSignatureScheme;

            //                     const Hash = SchemeHash(comptime_scheme);
            //                     const rsa = Certificate.rsa;
            //                     const components = try rsa.PublicKey.parseDer(main_cert_pub_key);
            //                     const exponent = components.exponent;
            //                     const modulus = components.modulus;
            //                     switch (modulus.len) {
            //                         inline 128, 256, 512 => |modulus_len| {
            //                             const key = try rsa.PublicKey.fromBytes(exponent, modulus);
            //                             const sig = rsa.PSSSignature.fromBytes(modulus_len, encoded_sig);
            //                             try rsa.PSSSignature.verify(modulus_len, sig, verify_bytes, key, Hash);
            //                         },
            //                         else => {
            //                             return error.TlsBadRsaSignatureBitCount;
            //                         },
            //                     }
            //                 },
            //                 inline .ed25519 => |comptime_scheme| {
            //                     if (main_cert_pub_key_algo != .curveEd25519) return error.TlsBadSignatureScheme;
            //                     const Eddsa = SchemeEddsa(comptime_scheme);
            //                     if (encoded_sig.len != Eddsa.Signature.encoded_length) return error.InvalidEncoding;
            //                     const sig = Eddsa.Signature.fromBytes(encoded_sig[0..Eddsa.Signature.encoded_length].*);
            //                     if (main_cert_pub_key.len != Eddsa.PublicKey.encoded_length) return error.InvalidEncoding;
            //                     const key = try Eddsa.PublicKey.fromBytes(main_cert_pub_key[0..Eddsa.PublicKey.encoded_length].*);
            //                     try sig.verify(verify_bytes, key);
            //                 },
            //                 else => {
            //                     return error.TlsBadSignatureScheme;
            //                 },
            //             }
            //         },
            //         .finished => {
            //             if (handshake_state != .finished) return error.TlsUnexpectedMessage;
            //             // This message is to trick buggy proxies into behaving correctly.
            //             const client_change_cipher_spec_msg = [_]u8{
            //                 @intFromEnum(tls.ContentType.change_cipher_spec),
            //                 0x03, 0x03, // legacy protocol version
            //                 0x00, 0x01, // length
            //                 0x01,
            //             };
            //             const app_cipher = switch (handshake_cipher) {
            //                 inline else => |*p, tag| c: {
            //                     const P = @TypeOf(p.*);
            //                     const finished_digest = p.transcript_hash.peek();
            //                     p.transcript_hash.update(wrapped_handshake);
            //                     const expected_server_verify_data = tls.hmac(P.Hmac, &finished_digest, p.server_finished_key);
            //                     if (!mem.eql(u8, &expected_server_verify_data, handshake_buf))
            //                         return error.TlsDecryptError;
            //                     const handshake_hash = p.transcript_hash.finalResult();
            //                     const verify_data = tls.hmac(P.Hmac, &handshake_hash, p.client_finished_key);
            //                     const out_cleartext = [_]u8{
            //                         @intFromEnum(tls.HandshakeType.finished),
            //                         0, 0, verify_data.len, // length
            //                     } ++ verify_data ++ [1]u8{@intFromEnum(tls.ContentType.handshake)};

            //                     const wrapped_len = out_cleartext.len + P.AEAD.tag_length;

            //                     var finished_msg = [_]u8{
            //                         @intFromEnum(tls.ContentType.application_data),
            //                         0x03, 0x03, // legacy protocol version
            //                         0, wrapped_len, // byte length of encrypted record
            //                     } ++ @as([wrapped_len]u8, undefined);

            //                     const ad = finished_msg[0..5];
            //                     const ciphertext = finished_msg[5..][0..out_cleartext.len];
            //                     const auth_tag = finished_msg[finished_msg.len - P.AEAD.tag_length ..];
            //                     const nonce = p.client_handshake_iv;
            //                     P.AEAD.encrypt(ciphertext, auth_tag, &out_cleartext, ad, nonce, p.client_handshake_key);

            //                     const both_msgs = client_change_cipher_spec_msg ++ finished_msg;
            //                     var both_msgs_vec = [_]std.os.iovec_const{.{
            //                         .iov_base = &both_msgs,
            //                         .iov_len = both_msgs.len,
            //                     }};
            //                     try stream.writevAll(&both_msgs_vec);

            //                     const client_secret = hkdfExpandLabel(P.Hkdf, p.master_secret, "c ap traffic", &handshake_hash, P.Hash.digest_length);
            //                     const server_secret = hkdfExpandLabel(P.Hkdf, p.master_secret, "s ap traffic", &handshake_hash, P.Hash.digest_length);
            //                     break :c @unionInit(tls.ApplicationCipher, @tagName(tag), .{
            //                         .client_secret = client_secret,
            //                         .server_secret = server_secret,
            //                         .client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length),
            //                         .server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length),
            //                         .client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length),
            //                         .server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length),
            //                     });
            //                 },
            //             };
            //             const leftover = decoder.rest();
            //             var client: Client = .{
            //                 .read_seq = 0,
            //                 .write_seq = 0,
            //                 .partial_cleartext_idx = 0,
            //                 .partial_ciphertext_idx = 0,
            //                 .partial_ciphertext_end = @intCast(leftover.len),
            //                 .received_close_notify = false,
            //                 .application_cipher = app_cipher,
            //                 .partially_read_buffer = undefined,
            //             };
            //             @memcpy(client.partially_read_buffer[0..leftover.len], leftover);
            //             return client;
            //         },
            //         else => {
            //             return error.TlsUnexpectedMessage;
            //         },
            //     }
            //     if (ctd.eof()) break;
            // }
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
            self.stream.handshake_type = .server_hello;
            try self.stream.readFragment();

            // > The value of TLSPlaintext.legacy_record_version MUST be ignored by all implementations.
            _ = try self.stream.read(tls.Version);
            const random = try self.stream.readAll(32);
            if (mem.eql(u8, random, &tls.ServerHello.hello_retry_request)) return error.TlsUnexpectedMessage; // `ClientHello` failed and we don't know how to rephrase it.
            const legacy_session_id = try self.stream.readSmallArray(u8);
            if (!mem.eql(u8, legacy_session_id, &key_pairs.session_id)) return error.TlsIllegalParameter;
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
                                const xksl = crypto.dh.X25519.public_length;
                                const hksl = xksl + crypto.kem.kyber_d00.Kyber768.ciphertext_length;
                                if (key_size != hksl)
                                    return error.TlsIllegalParameter;
                                const server_ks = try self.stream.readAll(hksl);

                                shared_key = &((crypto.dh.X25519.scalarmult(
                                    key_pairs.x25519.secret_key,
                                    server_ks[0..xksl].*,
                                ) catch return error.TlsDecryptFailure) ++ (key_pairs.kyber768d00.secret_key.decaps(
                                    server_ks[xksl..hksl],
                                ) catch return error.TlsDecryptFailure));
                            },
                            .x25519 => {
                                const ksl = crypto.dh.X25519.public_length;
                                if (key_size != ksl) return error.TlsIllegalParameter;
                                const server_pub_key = try self.stream.readAll(ksl);

                                shared_key = &(crypto.dh.X25519.scalarmult(
                                    key_pairs.x25519.secret_key,
                                    server_pub_key[0..ksl].*,
                                ) catch return error.TlsDecryptFailure);
                            },
                            .secp256r1 => {
                                const server_pub_key = try self.stream.readAll(key_size);

                                const PublicKey = crypto.sign.ecdsa.EcdsaP256Sha256.PublicKey;
                                const pk = PublicKey.fromSec1(server_pub_key) catch {
                                    return error.TlsDecryptFailure;
                                };
                                const mul = pk.p.mulPublic(key_pairs.secp256r1.secret_key.bytes, .big) catch {
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
                        _ = try self.stream.readAll(ext.len);
                    },
                }
            }

            if (supported_version != tls.Version.tls_1_3) return error.TlsIllegalParameter;
            if (shared_key == null) return error.TlsIllegalParameter;

            self.stream.transcript_hash.active = switch (cipher_suite) {
                .aes_128_gcm_sha256, .chacha20_poly1305_sha256, .aegis_128l_sha256 => .sha256,
                .aes_256_gcm_sha384 => .sha384,
                .aegis_256_sha512 => .sha512,
                else => return error.TlsIllegalParameter,
            };
            const hello_hash = self.stream.transcript_hash.peek();
            self.stream.handshake_cipher = tls.HandshakeCipher.init(cipher_suite, shared_key.?, hello_hash);
            self.stream.content_type = .application_data;
            self.stream.handshake_cipher.?.print();

            self.stream.handshake_type = .encrypted_extensions;
            try self.stream.readFragment();
            iter = try self.stream.extensions();
            while (try iter.next()) |ext|  {
                _ = try self.stream.readAll(ext.len);
            }

            // CertificateRequest*
            // Certificate*
            // CertificateVerify*
            // Finished
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

/// One of these potential hashes will be selected during the handshake as the transcript hash.
/// We init them before sending a single message to avoid having to store the `ClientHello` until
/// receiving `ServerHello`.
/// A nice benefit is decreased latency on hosts where one round trip takes longer than calling
/// `update` on each hashes.
pub const MultiHash = struct {
    sha256: sha2.Sha256 = sha2.Sha256.init(.{}),
    sha384: sha2.Sha384 = sha2.Sha384.init(.{}),
    sha512: sha2.Sha512 = sha2.Sha512.init(.{}),
    /// Chosen during handshake.
    active: enum { all, sha256, sha384, sha512 } = .all,

    const sha2 = crypto.hash.sha2;
    const Self = @This();

    pub fn update(self: *Self, bytes: []const u8) void {
        switch (self.active) {
            .all => {
                self.sha256.update(bytes);
                self.sha384.update(bytes);
                self.sha512.update(bytes);
            },
            .sha256 => self.sha256.update(bytes),
            .sha384 => self.sha384.update(bytes),
            .sha512 => self.sha512.update(bytes),
        }
    }

    pub fn peek(self: Self) []const u8 {
        return &switch (self.active) {
            .all => [_]u8{},
            .sha256 => self.sha256.peek(),
            .sha384 => self.sha384.peek(),
            .sha512 => self.sha512.peek(),
        };
    }
};

/// One of these potential key pairs will be selected during the handshake.
pub const KeyPairs = struct {
    hello_rand: [hello_rand_length]u8,
    session_id: [session_id_length]u8,
    kyber768d00: Kyber768,
    secp256r1: Secp256r1,
    x25519: X25519,

    const Self = @This();

    const hello_rand_length = 32;
    const session_id_length = 32;
    const X25519 = tls.NamedGroupT(.x25519).KeyPair;
    const Secp256r1 = tls.NamedGroupT(.secp256r1).KeyPair;
    const Kyber768 = tls.NamedGroupT(.x25519_kyber768d00).Kyber768.KeyPair;

    pub fn init() Self {
        var random_buffer: [
            hello_rand_length +
                session_id_length +
                Kyber768.seed_length +
                Secp256r1.seed_length +
                X25519.seed_length
        ]u8 = undefined;

        while (true) {
            crypto.random.bytes(&random_buffer);

            const split1 = hello_rand_length;
            const split2 = split1 + session_id_length;
            const split3 = split2 + Kyber768.seed_length;
            const split4 = split3 + Secp256r1.seed_length;

            return initAdvanced(
                random_buffer[0..split1].*,
                random_buffer[split1..split2].*,
                random_buffer[split2..split3].*,
                random_buffer[split3..split4].*,
                random_buffer[split4..].*,
            ) catch continue;
        }
    }

    pub fn initAdvanced(
        hello_rand: [hello_rand_length]u8,
        session_id: [session_id_length]u8,
        kyber_768_seed: [Kyber768.seed_length]u8,
        secp256r1_seed: [Secp256r1.seed_length]u8,
        x25519_seed: [X25519.seed_length]u8,
    ) !Self {
        return Self{
            .kyber768d00 = Kyber768.create(kyber_768_seed) catch {},
            .secp256r1 = Secp256r1.create(secp256r1_seed) catch |err| switch (err) {
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

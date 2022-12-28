const std = @import("../../std.zig");
const tls = std.crypto.tls;
const Client = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;

const ApplicationCipher = tls.ApplicationCipher;
const CipherSuite = tls.CipherSuite;
const ContentType = tls.ContentType;
const HandshakeCipher = tls.HandshakeCipher;
const max_ciphertext_len = tls.max_ciphertext_len;
const hkdfExpandLabel = tls.hkdfExpandLabel;
const int2 = tls.int2;
const int3 = tls.int3;
const array = tls.array;
const enum_array = tls.enum_array;
const Certificate = crypto.Certificate;

read_seq: u64,
write_seq: u64,
/// The number of partially read bytes inside `partially_read_buffer`.
partially_read_len: u15,
/// The number of cleartext bytes from decoding `partially_read_buffer` which
/// have already been transferred via read() calls. This implementation will
/// re-decrypt bytes from `partially_read_buffer` when the buffer supplied by
/// the read() API user is not large enough.
partial_cleartext_index: u15,
application_cipher: ApplicationCipher,
eof: bool,
/// The size is enough to contain exactly one TLSCiphertext record.
/// Contains encrypted bytes.
partially_read_buffer: [tls.max_ciphertext_record_len]u8,

/// `host` is only borrowed during this function call.
pub fn init(stream: net.Stream, ca_bundle: Certificate.Bundle, host: []const u8) !Client {
    const host_len = @intCast(u16, host.len);

    var random_buffer: [128]u8 = undefined;
    crypto.random.bytes(&random_buffer);
    const hello_rand = random_buffer[0..32].*;
    const legacy_session_id = random_buffer[32..64].*;
    const x25519_kp_seed = random_buffer[64..96].*;
    const secp256r1_kp_seed = random_buffer[96..128].*;

    const x25519_kp = crypto.dh.X25519.KeyPair.create(x25519_kp_seed) catch |err| switch (err) {
        // Only possible to happen if the private key is all zeroes.
        error.IdentityElement => return error.InsufficientEntropy,
    };
    const secp256r1_kp = crypto.sign.ecdsa.EcdsaP256Sha256.KeyPair.create(secp256r1_kp_seed) catch |err| switch (err) {
        // Only possible to happen if the private key is all zeroes.
        error.IdentityElement => return error.InsufficientEntropy,
    };

    const extensions_payload =
        tls.extension(.supported_versions, [_]u8{
        0x02, // byte length of supported versions
        0x03, 0x04, // TLS 1.3
    }) ++ tls.extension(.signature_algorithms, enum_array(tls.SignatureScheme, &.{
        .ecdsa_secp256r1_sha256,
        .ecdsa_secp384r1_sha384,
        .ecdsa_secp521r1_sha512,
        .rsa_pkcs1_sha256,
        .rsa_pkcs1_sha384,
        .rsa_pkcs1_sha512,
        .ed25519,
    })) ++ tls.extension(.supported_groups, enum_array(tls.NamedGroup, &.{
        .secp256r1,
        .x25519,
    })) ++ tls.extension(
        .key_share,
        array(1, int2(@enumToInt(tls.NamedGroup.x25519)) ++
            array(1, x25519_kp.public_key) ++
            int2(@enumToInt(tls.NamedGroup.secp256r1)) ++
            array(1, secp256r1_kp.public_key.toUncompressedSec1())),
    ) ++
        int2(@enumToInt(tls.ExtensionType.server_name)) ++
        int2(host_len + 5) ++ // byte length of this extension payload
        int2(host_len + 3) ++ // server_name_list byte count
        [1]u8{0x00} ++ // name_type
        int2(host_len);

    const extensions_header =
        int2(@intCast(u16, extensions_payload.len + host_len)) ++
        extensions_payload;

    const legacy_compression_methods = 0x0100;

    const client_hello =
        int2(@enumToInt(tls.ProtocolVersion.tls_1_2)) ++
        hello_rand ++
        [1]u8{32} ++ legacy_session_id ++
        cipher_suites ++
        int2(legacy_compression_methods) ++
        extensions_header;

    const out_handshake =
        [_]u8{@enumToInt(tls.HandshakeType.client_hello)} ++
        int3(@intCast(u24, client_hello.len + host_len)) ++
        client_hello;

    const plaintext_header = [_]u8{
        @enumToInt(ContentType.handshake),
        0x03, 0x01, // legacy_record_version
    } ++ int2(@intCast(u16, out_handshake.len + host_len)) ++ out_handshake;

    {
        var iovecs = [_]std.os.iovec_const{
            .{
                .iov_base = &plaintext_header,
                .iov_len = plaintext_header.len,
            },
            .{
                .iov_base = host.ptr,
                .iov_len = host.len,
            },
        };
        try stream.writevAll(&iovecs);
    }

    const client_hello_bytes1 = plaintext_header[5..];

    var handshake_cipher: HandshakeCipher = undefined;

    var handshake_buf: [8000]u8 = undefined;
    var len: usize = 0;
    var i: usize = i: {
        const plaintext = handshake_buf[0..5];
        len = try stream.readAtLeast(&handshake_buf, plaintext.len);
        if (len < plaintext.len) return error.EndOfStream;
        const ct = @intToEnum(ContentType, plaintext[0]);
        const frag_len = mem.readIntBig(u16, plaintext[3..][0..2]);
        const end = plaintext.len + frag_len;
        if (end > handshake_buf.len) return error.TlsRecordOverflow;
        if (end > len) {
            len += try stream.readAtLeast(handshake_buf[len..], end - len);
            if (end > len) return error.EndOfStream;
        }
        const frag = handshake_buf[plaintext.len..end];

        switch (ct) {
            .alert => {
                const level = @intToEnum(tls.AlertLevel, frag[0]);
                const desc = @intToEnum(tls.AlertDescription, frag[1]);
                std.debug.print("alert: {s} {s}\n", .{ @tagName(level), @tagName(desc) });
                return error.TlsAlert;
            },
            .handshake => {
                if (frag[0] != @enumToInt(tls.HandshakeType.server_hello)) {
                    return error.TlsUnexpectedMessage;
                }
                const length = mem.readIntBig(u24, frag[1..4]);
                if (4 + length != frag.len) return error.TlsBadLength;
                var i: usize = 4;
                const legacy_version = mem.readIntBig(u16, frag[i..][0..2]);
                i += 2;
                const random = frag[i..][0..32].*;
                i += 32;
                if (mem.eql(u8, &random, &tls.hello_retry_request_sequence)) {
                    @panic("TODO handle HelloRetryRequest");
                }
                const legacy_session_id_echo_len = frag[i];
                i += 1;
                if (legacy_session_id_echo_len != 32) return error.TlsIllegalParameter;
                const legacy_session_id_echo = frag[i..][0..32];
                if (!mem.eql(u8, legacy_session_id_echo, &legacy_session_id))
                    return error.TlsIllegalParameter;
                i += 32;
                const cipher_suite_int = mem.readIntBig(u16, frag[i..][0..2]);
                i += 2;
                const cipher_suite_tag = @intToEnum(CipherSuite, cipher_suite_int);
                const legacy_compression_method = frag[i];
                i += 1;
                _ = legacy_compression_method;
                const extensions_size = mem.readIntBig(u16, frag[i..][0..2]);
                i += 2;
                if (i + extensions_size != frag.len) return error.TlsBadLength;
                var supported_version: u16 = 0;
                var shared_key: [32]u8 = undefined;
                var have_shared_key = false;
                while (i < frag.len) {
                    const et = @intToEnum(tls.ExtensionType, mem.readIntBig(u16, frag[i..][0..2]));
                    i += 2;
                    const ext_size = mem.readIntBig(u16, frag[i..][0..2]);
                    i += 2;
                    const next_i = i + ext_size;
                    if (next_i > frag.len) return error.TlsBadLength;
                    switch (et) {
                        .supported_versions => {
                            if (supported_version != 0) return error.TlsIllegalParameter;
                            supported_version = mem.readIntBig(u16, frag[i..][0..2]);
                        },
                        .key_share => {
                            if (have_shared_key) return error.TlsIllegalParameter;
                            have_shared_key = true;
                            const named_group = @intToEnum(tls.NamedGroup, mem.readIntBig(u16, frag[i..][0..2]));
                            i += 2;
                            const key_size = mem.readIntBig(u16, frag[i..][0..2]);
                            i += 2;

                            switch (named_group) {
                                .x25519 => {
                                    if (key_size != 32) return error.TlsBadLength;
                                    const server_pub_key = frag[i..][0..32];

                                    shared_key = crypto.dh.X25519.scalarmult(
                                        x25519_kp.secret_key,
                                        server_pub_key.*,
                                    ) catch return error.TlsDecryptFailure;
                                },
                                .secp256r1 => {
                                    const server_pub_key = frag[i..][0..key_size];

                                    const PublicKey = crypto.sign.ecdsa.EcdsaP256Sha256.PublicKey;
                                    const pk = PublicKey.fromSec1(server_pub_key) catch {
                                        return error.TlsDecryptFailure;
                                    };
                                    const mul = pk.p.mulPublic(secp256r1_kp.secret_key.bytes, .Big) catch {
                                        return error.TlsDecryptFailure;
                                    };
                                    shared_key = mul.affineCoordinates().x.toBytes(.Big);
                                },
                                else => {
                                    //std.debug.print("named group: {x}\n", .{named_group});
                                    return error.TlsIllegalParameter;
                                },
                            }
                        },
                        else => {
                            std.debug.print("unexpected extension: {x}\n", .{et});
                        },
                    }
                    i = next_i;
                }
                if (!have_shared_key) return error.TlsIllegalParameter;
                const tls_version = if (supported_version == 0) legacy_version else supported_version;
                switch (tls_version) {
                    @enumToInt(tls.ProtocolVersion.tls_1_3) => {},
                    else => return error.TlsIllegalParameter,
                }

                switch (cipher_suite_tag) {
                    inline .AES_128_GCM_SHA256,
                    .AES_256_GCM_SHA384,
                    .CHACHA20_POLY1305_SHA256,
                    .AEGIS_256_SHA384,
                    .AEGIS_128L_SHA256,
                    => |tag| {
                        const P = std.meta.TagPayloadByName(HandshakeCipher, @tagName(tag));
                        handshake_cipher = @unionInit(HandshakeCipher, @tagName(tag), .{
                            .handshake_secret = undefined,
                            .master_secret = undefined,
                            .client_handshake_key = undefined,
                            .server_handshake_key = undefined,
                            .client_finished_key = undefined,
                            .server_finished_key = undefined,
                            .client_handshake_iv = undefined,
                            .server_handshake_iv = undefined,
                            .transcript_hash = P.Hash.init(.{}),
                        });
                        const p = &@field(handshake_cipher, @tagName(tag));
                        p.transcript_hash.update(client_hello_bytes1); // Client Hello part 1
                        p.transcript_hash.update(host); // Client Hello part 2
                        p.transcript_hash.update(frag); // Server Hello
                        const hello_hash = p.transcript_hash.peek();
                        const zeroes = [1]u8{0} ** P.Hash.digest_length;
                        const early_secret = P.Hkdf.extract(&[1]u8{0}, &zeroes);
                        const empty_hash = tls.emptyHash(P.Hash);
                        const hs_derived_secret = hkdfExpandLabel(P.Hkdf, early_secret, "derived", &empty_hash, P.Hash.digest_length);
                        p.handshake_secret = P.Hkdf.extract(&hs_derived_secret, &shared_key);
                        const ap_derived_secret = hkdfExpandLabel(P.Hkdf, p.handshake_secret, "derived", &empty_hash, P.Hash.digest_length);
                        p.master_secret = P.Hkdf.extract(&ap_derived_secret, &zeroes);
                        const client_secret = hkdfExpandLabel(P.Hkdf, p.handshake_secret, "c hs traffic", &hello_hash, P.Hash.digest_length);
                        const server_secret = hkdfExpandLabel(P.Hkdf, p.handshake_secret, "s hs traffic", &hello_hash, P.Hash.digest_length);
                        p.client_finished_key = hkdfExpandLabel(P.Hkdf, client_secret, "finished", "", P.Hmac.key_length);
                        p.server_finished_key = hkdfExpandLabel(P.Hkdf, server_secret, "finished", "", P.Hmac.key_length);
                        p.client_handshake_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length);
                        p.server_handshake_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length);
                        p.client_handshake_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length);
                        p.server_handshake_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length);
                        //std.debug.print("shared_key: {}\nhello_hash: {}\nearly_secret: {}\nempty_hash: {}\nderived_secret: {}\nhandshake_secret: {}\n client_secret: {}\n server_secret: {}\nclient_handshake_iv: {}\nserver_handshake_iv: {}\n", .{
                        //    std.fmt.fmtSliceHexLower(&shared_key),
                        //    std.fmt.fmtSliceHexLower(&hello_hash),
                        //    std.fmt.fmtSliceHexLower(&early_secret),
                        //    std.fmt.fmtSliceHexLower(&empty_hash),
                        //    std.fmt.fmtSliceHexLower(&hs_derived_secret),
                        //    std.fmt.fmtSliceHexLower(&p.handshake_secret),
                        //    std.fmt.fmtSliceHexLower(&client_secret),
                        //    std.fmt.fmtSliceHexLower(&server_secret),
                        //    std.fmt.fmtSliceHexLower(&p.client_handshake_iv),
                        //    std.fmt.fmtSliceHexLower(&p.server_handshake_iv),
                        //});
                    },
                    else => {
                        return error.TlsIllegalParameter;
                    },
                }
            },
            else => return error.TlsUnexpectedMessage,
        }
        break :i end;
    };

    // This is used for two purposes:
    // * Detect whether a certificate is the first one presented, in which case
    //   we need to verify the host name.
    // * Flip back and forth between the two cleartext buffers in order to keep
    //   the previous certificate in memory so that it can be verified by the
    //   next one.
    var cert_index: usize = 0;
    var read_seq: u64 = 0;
    var prev_cert: Certificate.Parsed = undefined;
    // Set to true once a trust chain has been established from the first
    // certificate to a root CA.
    const HandshakeState = enum {
        /// In this state we expect only an encrypted_extensions message.
        encrypted_extensions,
        /// In this state we expect certificate messages.
        certificate,
        /// In this state we expect certificate or certificate_verify messages.
        /// certificate messages are ignored since the trust chain is already
        /// established.
        trust_chain_established,
        /// In this state, we expect only the finished message.
        finished,
    };
    var handshake_state: HandshakeState = .encrypted_extensions;
    var cleartext_bufs: [2][8000]u8 = undefined;
    var main_cert_pub_key_algo: Certificate.AlgorithmCategory = undefined;
    var main_cert_pub_key_buf: [300]u8 = undefined;
    var main_cert_pub_key_len: u16 = undefined;

    while (true) {
        const end_hdr = i + 5;
        if (end_hdr > handshake_buf.len) return error.TlsRecordOverflow;
        if (end_hdr > len) {
            len += try stream.readAtLeast(handshake_buf[len..], end_hdr - len);
            if (end_hdr > len) return error.EndOfStream;
        }
        const ct = @intToEnum(ContentType, handshake_buf[i]);
        i += 1;
        const legacy_version = mem.readIntBig(u16, handshake_buf[i..][0..2]);
        i += 2;
        _ = legacy_version;
        const record_size = mem.readIntBig(u16, handshake_buf[i..][0..2]);
        i += 2;
        const end = i + record_size;
        if (end > handshake_buf.len) return error.TlsRecordOverflow;
        if (end > len) {
            len += try stream.readAtLeast(handshake_buf[len..], end - len);
            if (end > len) return error.EndOfStream;
        }
        switch (ct) {
            .change_cipher_spec => {
                if (record_size != 1) return error.TlsUnexpectedMessage;
                if (handshake_buf[i] != 0x01) return error.TlsUnexpectedMessage;
            },
            .application_data => {
                const cleartext_buf = &cleartext_bufs[cert_index % 2];

                const cleartext = switch (handshake_cipher) {
                    inline else => |*p| c: {
                        const P = @TypeOf(p.*);
                        const ciphertext_len = record_size - P.AEAD.tag_length;
                        const ciphertext = handshake_buf[i..][0..ciphertext_len];
                        i += ciphertext.len;
                        if (ciphertext.len > cleartext_buf.len) return error.TlsRecordOverflow;
                        const cleartext = cleartext_buf[0..ciphertext.len];
                        const auth_tag = handshake_buf[i..][0..P.AEAD.tag_length].*;
                        const V = @Vector(P.AEAD.nonce_length, u8);
                        const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                        const operand: V = pad ++ @bitCast([8]u8, big(read_seq));
                        read_seq += 1;
                        const nonce = @as(V, p.server_handshake_iv) ^ operand;
                        const ad = handshake_buf[end_hdr - 5 ..][0..5];
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag, ad, nonce, p.server_handshake_key) catch
                            return error.TlsBadRecordMac;
                        break :c cleartext;
                    },
                };

                const inner_ct = @intToEnum(ContentType, cleartext[cleartext.len - 1]);
                switch (inner_ct) {
                    .handshake => {
                        var ct_i: usize = 0;
                        while (true) {
                            const handshake_type = @intToEnum(tls.HandshakeType, cleartext[ct_i]);
                            ct_i += 1;
                            const handshake_len = mem.readIntBig(u24, cleartext[ct_i..][0..3]);
                            ct_i += 3;
                            const next_handshake_i = ct_i + handshake_len;
                            if (next_handshake_i > cleartext.len - 1)
                                return error.TlsBadLength;
                            const wrapped_handshake = cleartext[ct_i - 4 .. next_handshake_i];
                            const handshake = cleartext[ct_i..next_handshake_i];
                            switch (handshake_type) {
                                .encrypted_extensions => {
                                    if (handshake_state != .encrypted_extensions) return error.TlsUnexpectedMessage;
                                    handshake_state = .certificate;
                                    switch (handshake_cipher) {
                                        inline else => |*p| p.transcript_hash.update(wrapped_handshake),
                                    }
                                    const total_ext_size = mem.readIntBig(u16, handshake[0..2]);
                                    var hs_i: usize = 2;
                                    const end_ext_i = 2 + total_ext_size;
                                    while (hs_i < end_ext_i) {
                                        const et = @intToEnum(tls.ExtensionType, mem.readIntBig(u16, handshake[hs_i..][0..2]));
                                        hs_i += 2;
                                        const ext_size = mem.readIntBig(u16, handshake[hs_i..][0..2]);
                                        hs_i += 2;
                                        const next_ext_i = hs_i + ext_size;
                                        switch (et) {
                                            .server_name => {},
                                            else => {
                                                std.debug.print("encrypted extension: {any}\n", .{
                                                    et,
                                                });
                                            },
                                        }
                                        hs_i = next_ext_i;
                                    }
                                },
                                .certificate => cert: {
                                    switch (handshake_cipher) {
                                        inline else => |*p| p.transcript_hash.update(wrapped_handshake),
                                    }
                                    switch (handshake_state) {
                                        .certificate => {},
                                        .trust_chain_established => break :cert,
                                        else => return error.TlsUnexpectedMessage,
                                    }
                                    var hs_i: u32 = 0;
                                    const cert_req_ctx_len = handshake[hs_i];
                                    hs_i += 1;
                                    if (cert_req_ctx_len != 0) return error.TlsIllegalParameter;
                                    const certs_size = mem.readIntBig(u24, handshake[hs_i..][0..3]);
                                    hs_i += 3;
                                    const end_certs = hs_i + certs_size;
                                    while (hs_i < end_certs) {
                                        const cert_size = mem.readIntBig(u24, handshake[hs_i..][0..3]);
                                        hs_i += 3;
                                        const end_cert = hs_i + cert_size;

                                        const subject_cert: Certificate = .{
                                            .buffer = handshake,
                                            .index = hs_i,
                                        };
                                        const subject = try subject_cert.parse();
                                        if (cert_index == 0) {
                                            // Verify the host on the first certificate.
                                            if (!hostMatchesCommonName(host, subject.commonName())) {
                                                return error.TlsCertificateHostMismatch;
                                            }

                                            // Keep track of the public key for
                                            // the certificate_verify message
                                            // later.
                                            main_cert_pub_key_algo = subject.pub_key_algo;
                                            const pub_key = subject.pubKey();
                                            if (pub_key.len > main_cert_pub_key_buf.len)
                                                return error.CertificatePublicKeyInvalid;
                                            @memcpy(&main_cert_pub_key_buf, pub_key.ptr, pub_key.len);
                                            main_cert_pub_key_len = @intCast(@TypeOf(main_cert_pub_key_len), pub_key.len);
                                        } else {
                                            prev_cert.verify(subject) catch |err| {
                                                std.debug.print("unable to validate previous cert: {s}\n", .{
                                                    @errorName(err),
                                                });
                                                return err;
                                            };
                                        }

                                        if (ca_bundle.verify(subject)) |_| {
                                            handshake_state = .trust_chain_established;
                                            break :cert;
                                        } else |err| switch (err) {
                                            error.CertificateIssuerNotFound => {},
                                            else => |e| {
                                                std.debug.print("unable to validate cert against system root CAs: {s}\n", .{
                                                    @errorName(e),
                                                });
                                                return e;
                                            },
                                        }

                                        prev_cert = subject;
                                        cert_index += 1;

                                        hs_i = end_cert;
                                        const total_ext_size = mem.readIntBig(u16, handshake[hs_i..][0..2]);
                                        hs_i += 2;
                                        hs_i += total_ext_size;
                                    }
                                },
                                .certificate_verify => {
                                    switch (handshake_state) {
                                        .trust_chain_established => handshake_state = .finished,
                                        .certificate => return error.TlsCertificateNotVerified,
                                        else => return error.TlsUnexpectedMessage,
                                    }

                                    const algorithm = @intToEnum(tls.SignatureScheme, mem.readIntBig(u16, handshake[0..2]));
                                    const sig_len = mem.readIntBig(u16, handshake[2..4]);
                                    if (4 + sig_len > handshake.len) return error.TlsBadLength;
                                    const encoded_sig = handshake[4..][0..sig_len];
                                    const max_digest_len = 64;
                                    var verify_buffer =
                                        ([1]u8{0x20} ** 64) ++
                                        "TLS 1.3, server CertificateVerify\x00".* ++
                                        @as([max_digest_len]u8, undefined);

                                    const verify_bytes = switch (handshake_cipher) {
                                        inline else => |*p| v: {
                                            const transcript_digest = p.transcript_hash.peek();
                                            verify_buffer[verify_buffer.len - max_digest_len ..][0..transcript_digest.len].* = transcript_digest;
                                            p.transcript_hash.update(wrapped_handshake);
                                            break :v verify_buffer[0 .. verify_buffer.len - max_digest_len + transcript_digest.len];
                                        },
                                    };
                                    const main_cert_pub_key = main_cert_pub_key_buf[0..main_cert_pub_key_len];

                                    switch (algorithm) {
                                        .ecdsa_secp256r1_sha256 => {
                                            if (main_cert_pub_key_algo != .X9_62_id_ecPublicKey)
                                                return error.TlsBadSignatureAlgorithm;
                                            const P256 = std.crypto.sign.ecdsa.EcdsaP256Sha256;
                                            const sig = try P256.Signature.fromDer(encoded_sig);
                                            const key = try P256.PublicKey.fromSec1(main_cert_pub_key);
                                            try sig.verify(verify_bytes, key);
                                        },
                                        .rsa_pss_rsae_sha256 => {
                                            @panic("TODO signature algorithm: rsa_pss_rsae_sha256");
                                        },
                                        else => {
                                            //std.debug.print("signature algorithm: {any}\n", .{
                                            //    algorithm,
                                            //});
                                            return error.TlsBadSignatureAlgorithm;
                                        },
                                    }
                                },
                                .finished => {
                                    if (handshake_state != .finished) return error.TlsUnexpectedMessage;
                                    // This message is to trick buggy proxies into behaving correctly.
                                    const client_change_cipher_spec_msg = [_]u8{
                                        @enumToInt(ContentType.change_cipher_spec),
                                        0x03, 0x03, // legacy protocol version
                                        0x00, 0x01, // length
                                        0x01,
                                    };
                                    const app_cipher = switch (handshake_cipher) {
                                        inline else => |*p, tag| c: {
                                            const P = @TypeOf(p.*);
                                            const finished_digest = p.transcript_hash.peek();
                                            p.transcript_hash.update(wrapped_handshake);
                                            const expected_server_verify_data = tls.hmac(P.Hmac, &finished_digest, p.server_finished_key);
                                            if (!mem.eql(u8, &expected_server_verify_data, handshake))
                                                return error.TlsDecryptError;
                                            const handshake_hash = p.transcript_hash.finalResult();
                                            const verify_data = tls.hmac(P.Hmac, &handshake_hash, p.client_finished_key);
                                            const out_cleartext = [_]u8{
                                                @enumToInt(tls.HandshakeType.finished),
                                                0, 0, verify_data.len, // length
                                            } ++ verify_data ++ [1]u8{@enumToInt(ContentType.handshake)};

                                            const wrapped_len = out_cleartext.len + P.AEAD.tag_length;

                                            var finished_msg = [_]u8{
                                                @enumToInt(ContentType.application_data),
                                                0x03, 0x03, // legacy protocol version
                                                0, wrapped_len, // byte length of encrypted record
                                            } ++ @as([wrapped_len]u8, undefined);

                                            const ad = finished_msg[0..5];
                                            const ciphertext = finished_msg[5..][0..out_cleartext.len];
                                            const auth_tag = finished_msg[finished_msg.len - P.AEAD.tag_length ..];
                                            const nonce = p.client_handshake_iv;
                                            P.AEAD.encrypt(ciphertext, auth_tag, &out_cleartext, ad, nonce, p.client_handshake_key);

                                            const both_msgs = client_change_cipher_spec_msg ++ finished_msg;
                                            try stream.writeAll(&both_msgs);

                                            const client_secret = hkdfExpandLabel(P.Hkdf, p.master_secret, "c ap traffic", &handshake_hash, P.Hash.digest_length);
                                            const server_secret = hkdfExpandLabel(P.Hkdf, p.master_secret, "s ap traffic", &handshake_hash, P.Hash.digest_length);
                                            //std.debug.print("master_secret={}\nclient_secret={}\nserver_secret={}\n", .{
                                            //    std.fmt.fmtSliceHexLower(&p.master_secret),
                                            //    std.fmt.fmtSliceHexLower(&client_secret),
                                            //    std.fmt.fmtSliceHexLower(&server_secret),
                                            //});
                                            break :c @unionInit(ApplicationCipher, @tagName(tag), .{
                                                .client_secret = client_secret,
                                                .server_secret = server_secret,
                                                .client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length),
                                                .server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length),
                                                .client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length),
                                                .server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length),
                                            });
                                        },
                                    };
                                    var client: Client = .{
                                        .application_cipher = app_cipher,
                                        .read_seq = 0,
                                        .write_seq = 0,
                                        .partial_cleartext_index = 0,
                                        .partially_read_buffer = undefined,
                                        .partially_read_len = @intCast(u15, len - end),
                                        .eof = false,
                                    };
                                    mem.copy(u8, &client.partially_read_buffer, handshake_buf[len..end]);
                                    return client;
                                },
                                else => {
                                    return error.TlsUnexpectedMessage;
                                },
                            }
                            ct_i = next_handshake_i;
                            if (ct_i >= cleartext.len - 1) break;
                        }
                    },
                    else => {
                        std.debug.print("inner content type: {any}\n", .{inner_ct});
                        return error.TlsUnexpectedMessage;
                    },
                }
            },
            else => {
                std.debug.print("content type: {s}\n", .{@tagName(ct)});
                return error.TlsUnexpectedMessage;
            },
        }
        i = end;
    }

    return error.TlsHandshakeFailure;
}

pub fn write(c: *Client, stream: net.Stream, bytes: []const u8) !usize {
    var ciphertext_buf: [tls.max_ciphertext_record_len * 4]u8 = undefined;
    // Due to the trailing inner content type byte in the ciphertext, we need
    // an additional buffer for storing the cleartext into before encrypting.
    var cleartext_buf: [max_ciphertext_len]u8 = undefined;
    var iovecs_buf: [5]std.os.iovec_const = undefined;
    var ciphertext_end: usize = 0;
    var iovec_end: usize = 0;
    var bytes_i: usize = 0;
    // How many bytes are taken up by overhead per record.
    const overhead_len: usize = switch (c.application_cipher) {
        inline else => |*p| l: {
            const P = @TypeOf(p.*);
            const V = @Vector(P.AEAD.nonce_length, u8);
            const overhead_len = tls.ciphertext_record_header_len + P.AEAD.tag_length + 1;
            while (true) {
                const encrypted_content_len = @intCast(u16, @min(
                    @min(bytes.len - bytes_i, max_ciphertext_len - 1),
                    ciphertext_buf.len -
                        tls.ciphertext_record_header_len - P.AEAD.tag_length - ciphertext_end - 1,
                ));
                if (encrypted_content_len == 0) break :l overhead_len;

                mem.copy(u8, &cleartext_buf, bytes[bytes_i..][0..encrypted_content_len]);
                cleartext_buf[encrypted_content_len] = @enumToInt(ContentType.application_data);
                bytes_i += encrypted_content_len;
                const ciphertext_len = encrypted_content_len + 1;
                const cleartext = cleartext_buf[0..ciphertext_len];

                const record_start = ciphertext_end;
                const ad = ciphertext_buf[ciphertext_end..][0..5];
                ad.* =
                    [_]u8{@enumToInt(ContentType.application_data)} ++
                    int2(@enumToInt(tls.ProtocolVersion.tls_1_2)) ++
                    int2(ciphertext_len + P.AEAD.tag_length);
                ciphertext_end += ad.len;
                const ciphertext = ciphertext_buf[ciphertext_end..][0..ciphertext_len];
                ciphertext_end += ciphertext_len;
                const auth_tag = ciphertext_buf[ciphertext_end..][0..P.AEAD.tag_length];
                ciphertext_end += auth_tag.len;
                const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                const operand: V = pad ++ @bitCast([8]u8, big(c.write_seq));
                c.write_seq += 1; // TODO send key_update on overflow
                const nonce = @as(V, p.client_iv) ^ operand;
                P.AEAD.encrypt(ciphertext, auth_tag, cleartext, ad, nonce, p.client_key);
                //std.debug.print("seq: {d} nonce: {} client_key: {} client_iv: {} ad: {} auth_tag: {}\nserver_key: {} server_iv: {}\n", .{
                //    c.write_seq - 1,
                //    std.fmt.fmtSliceHexLower(&nonce),
                //    std.fmt.fmtSliceHexLower(&p.client_key),
                //    std.fmt.fmtSliceHexLower(&p.client_iv),
                //    std.fmt.fmtSliceHexLower(ad),
                //    std.fmt.fmtSliceHexLower(auth_tag),
                //    std.fmt.fmtSliceHexLower(&p.server_key),
                //    std.fmt.fmtSliceHexLower(&p.server_iv),
                //});

                const record = ciphertext_buf[record_start..ciphertext_end];
                iovecs_buf[iovec_end] = .{
                    .iov_base = record.ptr,
                    .iov_len = record.len,
                };
                iovec_end += 1;
            }
        },
    };

    // Ideally we would call writev exactly once here, however, we must ensure
    // that we don't return with a record partially written.
    var i: usize = 0;
    var total_amt: usize = 0;
    while (true) {
        var amt = try stream.writev(iovecs_buf[i..iovec_end]);
        while (amt >= iovecs_buf[i].iov_len) {
            const encrypted_amt = iovecs_buf[i].iov_len;
            total_amt += encrypted_amt - overhead_len;
            amt -= encrypted_amt;
            i += 1;
            // Rely on the property that iovecs delineate records, meaning that
            // if amt equals zero here, we have fortunately found ourselves
            // with a short read that aligns at the record boundary.
            if (i >= iovec_end or amt == 0) return total_amt;
        }
        iovecs_buf[i].iov_base += amt;
        iovecs_buf[i].iov_len -= amt;
    }
}

pub fn writeAll(c: *Client, stream: net.Stream, bytes: []const u8) !void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try c.write(stream, bytes[index..]);
    }
}

/// Returns the number of bytes read, calling the underlying read function the
/// minimal number of times until the buffer has at least `len` bytes filled.
/// If the number read is less than `len` it means the stream reached the end.
/// Reaching the end of the stream is not an error condition.
pub fn readAtLeast(c: *Client, stream: anytype, buffer: []u8, len: usize) !usize {
    assert(len <= buffer.len);
    if (c.eof) return 0;
    var index: usize = 0;
    while (index < len) {
        index += try c.readAdvanced(stream, buffer[index..]);
        if (c.eof) break;
    }
    return index;
}

pub fn read(c: *Client, stream: anytype, buffer: []u8) !usize {
    return readAtLeast(c, stream, buffer, 1);
}

/// Returns the number of bytes read. If the number read is smaller than
/// `buffer.len`, it means the stream reached the end. Reaching the end of the
/// stream is not an error condition.
pub fn readAll(c: *Client, stream: anytype, buffer: []u8) !usize {
    return readAtLeast(c, stream, buffer, buffer.len);
}

/// Returns number of bytes that have been read, populated inside `buffer`. A
/// return value of zero bytes does not mean end of stream. Instead, the `eof`
/// flag is set upon end of stream. The `eof` flag may be set after any call to
/// `read`, including when greater than zero bytes are returned, and this
/// function asserts that `eof` is `false`.
/// See `read` for a higher level function that has the same, familiar API
/// as other read functions, such as `std.fs.File.read`.
/// It is recommended to use a buffer size with length at least
/// `tls.max_ciphertext_len` bytes to avoid redundantly decrypting the same
/// encoded data.
pub fn readAdvanced(c: *Client, stream: net.Stream, buffer: []u8) !usize {
    assert(!c.eof);
    const prev_len = c.partially_read_len;
    // Ideally, this buffer would never be used. It is needed when `buffer` is too small
    // to fit the cleartext, which may be as large as `max_ciphertext_len`.
    var cleartext_stack_buffer: [max_ciphertext_len]u8 = undefined;
    // This buffer is typically used, except, as an optimization when a very large
    // `buffer` is provided, we use half of it for buffering ciphertext and the
    // other half for outputting cleartext.
    var in_stack_buffer: [max_ciphertext_len * 4]u8 = undefined;
    const half_buffer_len = buffer.len / 2;
    const out_in: struct { []u8, []u8 } = if (half_buffer_len >= in_stack_buffer.len) .{
        buffer[0..half_buffer_len],
        buffer[half_buffer_len..],
    } else .{
        buffer,
        &in_stack_buffer,
    };
    const out_buf = out_in[0];
    const in_buf = out_in[1];
    mem.copy(u8, in_buf, c.partially_read_buffer[0..prev_len]);

    // Capacity of output buffer, in records, rounded up.
    const buf_cap = (out_buf.len +| (max_ciphertext_len - 1)) / max_ciphertext_len;
    const wanted_read_len = buf_cap * (max_ciphertext_len + tls.ciphertext_record_header_len);
    const ask_len = @max(wanted_read_len, cleartext_stack_buffer.len);
    const ask_slice = in_buf[prev_len..][0..@min(ask_len, in_buf.len - prev_len)];
    assert(ask_slice.len > 0);
    const frag = frag: {
        if (prev_len >= 5) {
            const record_size = mem.readIntBig(u16, in_buf[3..][0..2]);
            if (prev_len >= 5 + record_size) {
                // We can use our buffered data without calling read().
                break :frag in_buf[0..prev_len];
            }
        }
        const actual_read_len = try stream.read(ask_slice);
        if (actual_read_len == 0) {
            // This is either a truncation attack, or a bug in the server.
            return error.TlsConnectionTruncated;
        }
        break :frag in_buf[0 .. prev_len + actual_read_len];
    };
    var in: usize = 0;
    var out: usize = 0;

    while (true) {
        if (in + tls.ciphertext_record_header_len > frag.len) {
            return finishRead(c, frag, in, out);
        }
        const record_start = in;
        const ct = @intToEnum(ContentType, frag[in]);
        in += 1;
        const legacy_version = mem.readIntBig(u16, frag[in..][0..2]);
        in += 2;
        _ = legacy_version;
        const record_size = mem.readIntBig(u16, frag[in..][0..2]);
        in += 2;
        const end = in + record_size;
        if (end > frag.len) {
            if (record_size > max_ciphertext_len) return error.TlsRecordOverflow;
            return finishRead(c, frag, in, out);
        }
        switch (ct) {
            .alert => {
                @panic("TODO handle an alert here");
            },
            .application_data => {
                const cleartext = switch (c.application_cipher) {
                    inline else => |*p| c: {
                        const P = @TypeOf(p.*);
                        const V = @Vector(P.AEAD.nonce_length, u8);
                        const ad = frag[in - 5 ..][0..5];
                        const ciphertext_len = record_size - P.AEAD.tag_length;
                        const ciphertext = frag[in..][0..ciphertext_len];
                        in += ciphertext_len;
                        const auth_tag = frag[in..][0..P.AEAD.tag_length].*;
                        const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                        // Here we use read_seq and then intentionally don't
                        // increment it until later when it is certain the same
                        // ciphertext does not need to be decrypted again.
                        const operand: V = pad ++ @bitCast([8]u8, big(c.read_seq));
                        const nonce: [P.AEAD.nonce_length]u8 = @as(V, p.server_iv) ^ operand;
                        const cleartext_buf = if (c.partial_cleartext_index == 0 and out + ciphertext.len <= out_buf.len)
                            out_buf[out..]
                        else
                            &cleartext_stack_buffer;
                        const cleartext = cleartext_buf[0..ciphertext.len];
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag, ad, nonce, p.server_key) catch
                            return error.TlsBadRecordMac;
                        break :c cleartext;
                    },
                };

                const inner_ct = @intToEnum(ContentType, cleartext[cleartext.len - 1]);
                switch (inner_ct) {
                    .alert => {
                        c.read_seq += 1;
                        const level = @intToEnum(tls.AlertLevel, out_buf[out]);
                        const desc = @intToEnum(tls.AlertDescription, out_buf[out + 1]);
                        if (desc == .close_notify) {
                            c.eof = true;
                            return out;
                        }
                        std.debug.print("alert: {s} {s}\n", .{ @tagName(level), @tagName(desc) });
                        return error.TlsAlert;
                    },
                    .handshake => {
                        c.read_seq += 1;
                        var ct_i: usize = 0;
                        while (true) {
                            const handshake_type = @intToEnum(tls.HandshakeType, cleartext[ct_i]);
                            ct_i += 1;
                            const handshake_len = mem.readIntBig(u24, cleartext[ct_i..][0..3]);
                            ct_i += 3;
                            const next_handshake_i = ct_i + handshake_len;
                            if (next_handshake_i > cleartext.len - 1)
                                return error.TlsBadLength;
                            const handshake = cleartext[ct_i..next_handshake_i];
                            switch (handshake_type) {
                                .new_session_ticket => {
                                    // This client implementation ignores new session tickets.
                                },
                                .key_update => {
                                    switch (c.application_cipher) {
                                        inline else => |*p| {
                                            const P = @TypeOf(p.*);
                                            const server_secret = hkdfExpandLabel(P.Hkdf, p.server_secret, "traffic upd", "", P.Hash.digest_length);
                                            p.server_secret = server_secret;
                                            p.server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length);
                                            p.server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length);
                                        },
                                    }
                                    c.read_seq = 0;

                                    switch (@intToEnum(tls.KeyUpdateRequest, handshake[0])) {
                                        .update_requested => {
                                            switch (c.application_cipher) {
                                                inline else => |*p| {
                                                    const P = @TypeOf(p.*);
                                                    const client_secret = hkdfExpandLabel(P.Hkdf, p.client_secret, "traffic upd", "", P.Hash.digest_length);
                                                    p.client_secret = client_secret;
                                                    p.client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length);
                                                    p.client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length);
                                                },
                                            }
                                            c.write_seq = 0;
                                        },
                                        .update_not_requested => {},
                                        _ => return error.TlsIllegalParameter,
                                    }
                                },
                                else => {
                                    return error.TlsUnexpectedMessage;
                                },
                            }
                            ct_i = next_handshake_i;
                            if (ct_i >= cleartext.len - 1) break;
                        }
                    },
                    .application_data => {
                        // Determine whether the output buffer or a stack
                        // buffer was used for storing the cleartext.
                        if (c.partial_cleartext_index == 0 and
                            out + cleartext.len <= out_buf.len)
                        {
                            // Output buffer was used directly which means no
                            // memory copying needs to occur, and we can move
                            // on to the next ciphertext record.
                            out += cleartext.len - 1;
                            c.read_seq += 1;
                        } else {
                            // Stack buffer was used, so we must copy to the output buffer.
                            const dest = out_buf[out..];
                            const rest = cleartext[c.partial_cleartext_index..];
                            const src = rest[0..@min(rest.len, dest.len)];
                            mem.copy(u8, dest, src);
                            out += src.len;
                            c.partial_cleartext_index = @intCast(
                                @TypeOf(c.partial_cleartext_index),
                                c.partial_cleartext_index + src.len,
                            );
                            if (c.partial_cleartext_index >= cleartext.len) {
                                c.partial_cleartext_index = 0;
                                c.read_seq += 1;
                            } else {
                                in = record_start;
                                return finishRead(c, frag, in, out);
                            }
                        }
                    },
                    else => {
                        std.debug.print("inner content type: {d}\n", .{inner_ct});
                        return error.TlsUnexpectedMessage;
                    },
                }
            },
            else => {
                std.debug.print("unexpected ct: {any}\n", .{ct});
                return error.TlsUnexpectedMessage;
            },
        }
        in = end;
    }
}

fn finishRead(c: *Client, frag: []const u8, in: usize, out: usize) usize {
    const saved_buf = frag[in..];
    mem.copy(u8, &c.partially_read_buffer, saved_buf);
    c.partially_read_len = @intCast(u15, saved_buf.len);
    return out;
}

fn hostMatchesCommonName(host: []const u8, common_name: []const u8) bool {
    if (mem.eql(u8, common_name, host)) {
        return true; // exact match
    }

    if (mem.startsWith(u8, common_name, "*.")) {
        // wildcard certificate, matches any subdomain
        if (mem.endsWith(u8, host, common_name[1..])) {
            // The host has a subdomain, but the important part matches.
            return true;
        }
        if (mem.eql(u8, common_name[2..], host)) {
            // The host has no subdomain and matches exactly.
            return true;
        }
    }

    return false;
}

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

inline fn big(x: anytype) @TypeOf(x) {
    return switch (native_endian) {
        .Big => x,
        .Little => @byteSwap(x),
    };
}

/// The priority order here is chosen based on what crypto algorithms Zig has
/// available in the standard library as well as what is faster. Following are
/// a few data points on the relative performance of these algorithms.
///
/// Measurement taken with 0.11.0-dev.810+c2f5848fe
/// on x86_64-linux Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz:
/// zig run .lib/std/crypto/benchmark.zig -OReleaseFast
///       aegis-128l:      15382 MiB/s
///        aegis-256:       9553 MiB/s
///       aes128-gcm:       3721 MiB/s
///       aes256-gcm:       3010 MiB/s
/// chacha20Poly1305:        597 MiB/s
///
/// Measurement taken with 0.11.0-dev.810+c2f5848fe
/// on x86_64-linux Intel(R) Core(TM) i9-9980HK CPU @ 2.40GHz:
/// zig run .lib/std/crypto/benchmark.zig -OReleaseFast -mcpu=baseline
///       aegis-128l:        629 MiB/s
/// chacha20Poly1305:        529 MiB/s
///        aegis-256:        461 MiB/s
///       aes128-gcm:        138 MiB/s
///       aes256-gcm:        120 MiB/s
const cipher_suites = enum_array(tls.CipherSuite, &.{
    .AEGIS_128L_SHA256,
    .AEGIS_256_SHA384,
    .AES_128_GCM_SHA256,
    .AES_256_GCM_SHA384,
    .CHACHA20_POLY1305_SHA256,
});

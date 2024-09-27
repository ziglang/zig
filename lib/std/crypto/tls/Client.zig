const std = @import("../../std.zig");
const tls = std.crypto.tls;
const Client = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;

const max_ciphertext_len = tls.max_ciphertext_len;
const hkdfExpandLabel = tls.hkdfExpandLabel;
const int2 = tls.int2;
const int3 = tls.int3;
const array = tls.array;
const enum_array = tls.enum_array;

read_seq: u64,
write_seq: u64,
/// The starting index of cleartext bytes inside `partially_read_buffer`.
partial_cleartext_idx: u15,
/// The ending index of cleartext bytes inside `partially_read_buffer` as well
/// as the starting index of ciphertext bytes.
partial_ciphertext_idx: u15,
/// The ending index of ciphertext bytes inside `partially_read_buffer`.
partial_ciphertext_end: u15,
/// When this is true, the stream may still not be at the end because there
/// may be data in `partially_read_buffer`.
received_close_notify: bool,
/// By default, reaching the end-of-stream when reading from the server will
/// cause `error.TlsConnectionTruncated` to be returned, unless a close_notify
/// message has been received. By setting this flag to `true`, instead, the
/// end-of-stream will be forwarded to the application layer above TLS.
/// This makes the application vulnerable to truncation attacks unless the
/// application layer itself verifies that the amount of data received equals
/// the amount of data expected, such as HTTP with the Content-Length header.
allow_truncation_attacks: bool = false,
application_cipher: tls.ApplicationCipher,
/// The size is enough to contain exactly one TLSCiphertext record.
/// This buffer is segmented into four parts:
/// 0. unused
/// 1. cleartext
/// 2. ciphertext
/// 3. unused
/// The fields `partial_cleartext_idx`, `partial_ciphertext_idx`, and
/// `partial_ciphertext_end` describe the span of the segments.
partially_read_buffer: [tls.max_ciphertext_record_len]u8,

/// This is an example of the type that is needed by the read and write
/// functions. It can have any fields but it must at least have these
/// functions.
///
/// Note that `std.net.Stream` conforms to this interface.
///
/// This declaration serves as documentation only.
pub const StreamInterface = struct {
    /// Can be any error set.
    pub const ReadError = error{};

    /// Returns the number of bytes read. The number read may be less than the
    /// buffer space provided. End-of-stream is indicated by a return value of 0.
    ///
    /// The `iovecs` parameter is mutable because so that function may to
    /// mutate the fields in order to handle partial reads from the underlying
    /// stream layer.
    pub fn readv(this: @This(), iovecs: []std.posix.iovec) ReadError!usize {
        _ = .{ this, iovecs };
        @panic("unimplemented");
    }

    /// Can be any error set.
    pub const WriteError = error{};

    /// Returns the number of bytes read, which may be less than the buffer
    /// space provided. A short read does not indicate end-of-stream.
    pub fn writev(this: @This(), iovecs: []const std.posix.iovec_const) WriteError!usize {
        _ = .{ this, iovecs };
        @panic("unimplemented");
    }

    /// Returns the number of bytes read, which may be less than the buffer
    /// space provided, indicating end-of-stream.
    /// The `iovecs` parameter is mutable in case this function needs to mutate
    /// the fields in order to handle partial writes from the underlying layer.
    pub fn writevAll(this: @This(), iovecs: []std.posix.iovec_const) WriteError!usize {
        // This can be implemented in terms of writev, or specialized if desired.
        _ = .{ this, iovecs };
        @panic("unimplemented");
    }
};

pub fn InitError(comptime Stream: type) type {
    return std.mem.Allocator.Error || Stream.WriteError || Stream.ReadError || tls.AlertDescription.Error || error{
        InsufficientEntropy,
        DiskQuota,
        LockViolation,
        NotOpenForWriting,
        TlsUnexpectedMessage,
        TlsIllegalParameter,
        TlsDecryptFailure,
        TlsRecordOverflow,
        TlsBadRecordMac,
        CertificateFieldHasInvalidLength,
        CertificateHostMismatch,
        CertificatePublicKeyInvalid,
        CertificateExpired,
        CertificateFieldHasWrongDataType,
        CertificateIssuerMismatch,
        CertificateNotYetValid,
        CertificateSignatureAlgorithmMismatch,
        CertificateSignatureAlgorithmUnsupported,
        CertificateSignatureInvalid,
        CertificateSignatureInvalidLength,
        CertificateSignatureNamedCurveUnsupported,
        CertificateSignatureUnsupportedBitCount,
        TlsCertificateNotVerified,
        TlsBadSignatureScheme,
        TlsBadRsaSignatureBitCount,
        InvalidEncoding,
        IdentityElement,
        SignatureVerificationFailed,
        TlsDecryptError,
        TlsConnectionTruncated,
        TlsDecodeError,
        UnsupportedCertificateVersion,
        CertificateTimeInvalid,
        CertificateHasUnrecognizedObjectId,
        CertificateHasInvalidBitString,
        MessageTooLong,
        NegativeIntoUnsigned,
        TargetTooSmall,
        BufferTooSmall,
        InvalidSignature,
        NotSquare,
        NonCanonical,
        WeakPublicKey,
    };
}

/// Initiates a TLS handshake and establishes a TLSv1.3 session with `stream`, which
/// must conform to `StreamInterface`.
///
/// `host` is only borrowed during this function call.
pub fn init(stream: anytype, ca_bundle: Certificate.Bundle, host: []const u8) InitError(@TypeOf(stream))!Client {
    const host_len: u16 = @intCast(host.len);

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
    const ml_kem768_kp = crypto.kem.ml_kem.MLKem768.KeyPair.create(null) catch {};

    const extensions_payload =
        tls.extension(.supported_versions, [_]u8{
        0x02, // byte length of supported versions
        0x03, 0x04, // TLS 1.3
    }) ++ tls.extension(.signature_algorithms, enum_array(tls.SignatureScheme, &.{
        .ecdsa_secp256r1_sha256,
        .ecdsa_secp384r1_sha384,
        .rsa_pss_rsae_sha256,
        .rsa_pss_rsae_sha384,
        .rsa_pss_rsae_sha512,
        .ed25519,
    })) ++ tls.extension(.supported_groups, enum_array(tls.NamedGroup, &.{
        .x25519_ml_kem768,
        .secp256r1,
        .x25519,
    })) ++ tls.extension(
        .key_share,
        array(1, int2(@intFromEnum(tls.NamedGroup.x25519)) ++
            array(1, x25519_kp.public_key) ++
            int2(@intFromEnum(tls.NamedGroup.secp256r1)) ++
            array(1, secp256r1_kp.public_key.toUncompressedSec1()) ++
            int2(@intFromEnum(tls.NamedGroup.x25519_ml_kem768)) ++
            array(1, x25519_kp.public_key ++ ml_kem768_kp.public_key.toBytes())),
    ) ++
        int2(@intFromEnum(tls.ExtensionType.server_name)) ++
        int2(host_len + 5) ++ // byte length of this extension payload
        int2(host_len + 3) ++ // server_name_list byte count
        [1]u8{0x00} ++ // name_type
        int2(host_len);

    const extensions_header =
        int2(@intCast(extensions_payload.len + host_len)) ++
        extensions_payload;

    const legacy_compression_methods = 0x0100;

    const client_hello =
        int2(@intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
        hello_rand ++
        [1]u8{32} ++ legacy_session_id ++
        cipher_suites ++
        int2(legacy_compression_methods) ++
        extensions_header;

    const out_handshake =
        [_]u8{@intFromEnum(tls.HandshakeType.client_hello)} ++
        int3(@intCast(client_hello.len + host_len)) ++
        client_hello;

    const plaintext_header = [_]u8{
        @intFromEnum(tls.ContentType.handshake),
        0x03, 0x01, // legacy_record_version
    } ++ int2(@intCast(out_handshake.len + host_len)) ++ out_handshake;

    {
        var iovecs = [_]std.posix.iovec_const{
            .{
                .base = &plaintext_header,
                .len = plaintext_header.len,
            },
            .{
                .base = host.ptr,
                .len = host.len,
            },
        };
        try stream.writevAll(&iovecs);
    }

    const client_hello_bytes1 = plaintext_header[5..];

    var handshake_cipher: tls.HandshakeCipher = undefined;
    var handshake_buffer: [8000]u8 = undefined;
    var d: tls.Decoder = .{ .buf = &handshake_buffer };
    {
        try d.readAtLeastOurAmt(stream, tls.record_header_len);
        const ct = d.decode(tls.ContentType);
        d.skip(2); // legacy_record_version
        const record_len = d.decode(u16);
        try d.readAtLeast(stream, record_len);
        const server_hello_fragment = d.buf[d.idx..][0..record_len];
        var ptd = try d.sub(record_len);
        switch (ct) {
            .alert => {
                try ptd.ensure(2);
                const level = ptd.decode(tls.AlertLevel);
                const desc = ptd.decode(tls.AlertDescription);
                _ = level;

                // if this isn't a error alert, then it's a closure alert, which makes no sense in a handshake
                try desc.toError();
                // TODO: handle server-side closures
                return error.TlsUnexpectedMessage;
            },
            .handshake => {
                try ptd.ensure(4);
                const handshake_type = ptd.decode(tls.HandshakeType);
                if (handshake_type != .server_hello) return error.TlsUnexpectedMessage;
                const length = ptd.decode(u24);
                var hsd = try ptd.sub(length);
                try hsd.ensure(2 + 32 + 1 + 32 + 2 + 1 + 2);
                const legacy_version = hsd.decode(u16);
                const random = hsd.array(32);
                if (mem.eql(u8, random, &tls.hello_retry_request_sequence)) {
                    // This is a HelloRetryRequest message. This client implementation
                    // does not expect to get one.
                    return error.TlsUnexpectedMessage;
                }
                const legacy_session_id_echo_len = hsd.decode(u8);
                if (legacy_session_id_echo_len != 32) return error.TlsIllegalParameter;
                const legacy_session_id_echo = hsd.array(32);
                if (!mem.eql(u8, legacy_session_id_echo, &legacy_session_id))
                    return error.TlsIllegalParameter;
                const cipher_suite_tag = hsd.decode(tls.CipherSuite);
                hsd.skip(1); // legacy_compression_method
                const extensions_size = hsd.decode(u16);
                var all_extd = try hsd.sub(extensions_size);
                var supported_version: u16 = 0;
                var shared_key: []const u8 = undefined;
                var have_shared_key = false;
                while (!all_extd.eof()) {
                    try all_extd.ensure(2 + 2);
                    const et = all_extd.decode(tls.ExtensionType);
                    const ext_size = all_extd.decode(u16);
                    var extd = try all_extd.sub(ext_size);
                    switch (et) {
                        .supported_versions => {
                            if (supported_version != 0) return error.TlsIllegalParameter;
                            try extd.ensure(2);
                            supported_version = extd.decode(u16);
                        },
                        .key_share => {
                            if (have_shared_key) return error.TlsIllegalParameter;
                            have_shared_key = true;
                            try extd.ensure(4);
                            const named_group = extd.decode(tls.NamedGroup);
                            const key_size = extd.decode(u16);
                            try extd.ensure(key_size);
                            switch (named_group) {
                                .x25519_ml_kem768 => {
                                    const xksl = crypto.dh.X25519.public_length;
                                    const hksl = xksl + crypto.kem.ml_kem.MLKem768.ciphertext_length;
                                    if (key_size != hksl)
                                        return error.TlsIllegalParameter;
                                    const server_ks = extd.array(hksl);

                                    shared_key = &((crypto.dh.X25519.scalarmult(
                                        x25519_kp.secret_key,
                                        server_ks[0..xksl].*,
                                    ) catch return error.TlsDecryptFailure) ++ (ml_kem768_kp.secret_key.decaps(
                                        server_ks[xksl..hksl],
                                    ) catch return error.TlsDecryptFailure));
                                },
                                .x25519 => {
                                    const ksl = crypto.dh.X25519.public_length;
                                    if (key_size != ksl) return error.TlsIllegalParameter;
                                    const server_pub_key = extd.array(ksl);

                                    shared_key = &(crypto.dh.X25519.scalarmult(
                                        x25519_kp.secret_key,
                                        server_pub_key.*,
                                    ) catch return error.TlsDecryptFailure);
                                },
                                .secp256r1 => {
                                    const server_pub_key = extd.slice(key_size);

                                    const PublicKey = crypto.sign.ecdsa.EcdsaP256Sha256.PublicKey;
                                    const pk = PublicKey.fromSec1(server_pub_key) catch {
                                        return error.TlsDecryptFailure;
                                    };
                                    const mul = pk.p.mulPublic(secp256r1_kp.secret_key.bytes, .big) catch {
                                        return error.TlsDecryptFailure;
                                    };
                                    shared_key = &mul.affineCoordinates().x.toBytes(.big);
                                },
                                else => {
                                    return error.TlsIllegalParameter;
                                },
                            }
                        },
                        else => {},
                    }
                }
                if (!have_shared_key) return error.TlsIllegalParameter;

                const tls_version = if (supported_version == 0) legacy_version else supported_version;
                if (tls_version != @intFromEnum(tls.ProtocolVersion.tls_1_3))
                    return error.TlsIllegalParameter;

                switch (cipher_suite_tag) {
                    inline .AES_128_GCM_SHA256,
                    .AES_256_GCM_SHA384,
                    .CHACHA20_POLY1305_SHA256,
                    .AEGIS_256_SHA512,
                    .AEGIS_128L_SHA256,
                    => |tag| {
                        const P = std.meta.TagPayloadByName(tls.HandshakeCipher, @tagName(tag));
                        handshake_cipher = @unionInit(tls.HandshakeCipher, @tagName(tag), .{
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
                        p.transcript_hash.update(server_hello_fragment);
                        const hello_hash = p.transcript_hash.peek();
                        const zeroes = [1]u8{0} ** P.Hash.digest_length;
                        const early_secret = P.Hkdf.extract(&[1]u8{0}, &zeroes);
                        const empty_hash = tls.emptyHash(P.Hash);
                        const hs_derived_secret = hkdfExpandLabel(P.Hkdf, early_secret, "derived", &empty_hash, P.Hash.digest_length);
                        p.handshake_secret = P.Hkdf.extract(&hs_derived_secret, shared_key);
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
                    },
                    else => {
                        return error.TlsIllegalParameter;
                    },
                }
            },
            else => return error.TlsUnexpectedMessage,
        }
    }

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
    var main_cert_pub_key_buf: [600]u8 = undefined;
    var main_cert_pub_key_len: u16 = undefined;
    const now_sec = std.time.timestamp();

    while (true) {
        try d.readAtLeastOurAmt(stream, tls.record_header_len);
        const record_header = d.buf[d.idx..][0..5];
        const ct = d.decode(tls.ContentType);
        d.skip(2); // legacy_version
        const record_len = d.decode(u16);
        try d.readAtLeast(stream, record_len);
        var record_decoder = try d.sub(record_len);
        switch (ct) {
            .change_cipher_spec => {
                try record_decoder.ensure(1);
                if (record_decoder.decode(u8) != 0x01) return error.TlsIllegalParameter;
            },
            .application_data => {
                const cleartext_buf = &cleartext_bufs[cert_index % 2];

                const cleartext = switch (handshake_cipher) {
                    inline else => |*p| c: {
                        const P = @TypeOf(p.*);
                        const ciphertext_len = record_len - P.AEAD.tag_length;
                        try record_decoder.ensure(ciphertext_len + P.AEAD.tag_length);
                        const ciphertext = record_decoder.slice(ciphertext_len);
                        if (ciphertext.len > cleartext_buf.len) return error.TlsRecordOverflow;
                        const cleartext = cleartext_buf[0..ciphertext.len];
                        const auth_tag = record_decoder.array(P.AEAD.tag_length).*;
                        const nonce = if (builtin.zig_backend == .stage2_x86_64 and
                            P.AEAD.nonce_length > comptime std.simd.suggestVectorLength(u8) orelse 1)
                        nonce: {
                            var nonce = p.server_handshake_iv;
                            const operand = std.mem.readInt(u64, nonce[nonce.len - 8 ..], .big);
                            std.mem.writeInt(u64, nonce[nonce.len - 8 ..], operand ^ read_seq, .big);
                            break :nonce nonce;
                        } else nonce: {
                            const V = @Vector(P.AEAD.nonce_length, u8);
                            const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                            const operand: V = pad ++ @as([8]u8, @bitCast(big(read_seq)));
                            break :nonce @as(V, p.server_handshake_iv) ^ operand;
                        };
                        read_seq += 1;
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag, record_header, nonce, p.server_handshake_key) catch
                            return error.TlsBadRecordMac;
                        break :c @constCast(mem.trimRight(u8, cleartext, "\x00"));
                    },
                };

                const inner_ct: tls.ContentType = @enumFromInt(cleartext[cleartext.len - 1]);
                if (inner_ct != .handshake) return error.TlsUnexpectedMessage;

                var ctd = tls.Decoder.fromTheirSlice(cleartext[0 .. cleartext.len - 1]);
                while (true) {
                    try ctd.ensure(4);
                    const handshake_type = ctd.decode(tls.HandshakeType);
                    const handshake_len = ctd.decode(u24);
                    var hsd = try ctd.sub(handshake_len);
                    const wrapped_handshake = ctd.buf[ctd.idx - handshake_len - 4 .. ctd.idx];
                    const handshake = ctd.buf[ctd.idx - handshake_len .. ctd.idx];
                    switch (handshake_type) {
                        .encrypted_extensions => {
                            if (handshake_state != .encrypted_extensions) return error.TlsUnexpectedMessage;
                            handshake_state = .certificate;
                            switch (handshake_cipher) {
                                inline else => |*p| p.transcript_hash.update(wrapped_handshake),
                            }
                            try hsd.ensure(2);
                            const total_ext_size = hsd.decode(u16);
                            var all_extd = try hsd.sub(total_ext_size);
                            while (!all_extd.eof()) {
                                try all_extd.ensure(4);
                                const et = all_extd.decode(tls.ExtensionType);
                                const ext_size = all_extd.decode(u16);
                                const extd = try all_extd.sub(ext_size);
                                _ = extd;
                                switch (et) {
                                    .server_name => {},
                                    else => {},
                                }
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
                            try hsd.ensure(1 + 4);
                            const cert_req_ctx_len = hsd.decode(u8);
                            if (cert_req_ctx_len != 0) return error.TlsIllegalParameter;
                            const certs_size = hsd.decode(u24);
                            var certs_decoder = try hsd.sub(certs_size);
                            while (!certs_decoder.eof()) {
                                try certs_decoder.ensure(3);
                                const cert_size = certs_decoder.decode(u24);
                                const certd = try certs_decoder.sub(cert_size);

                                const subject_cert: Certificate = .{
                                    .buffer = certd.buf,
                                    .index = @intCast(certd.idx),
                                };
                                const subject = try subject_cert.parse();
                                if (cert_index == 0) {
                                    // Verify the host on the first certificate.
                                    try subject.verifyHostName(host);

                                    // Keep track of the public key for the
                                    // certificate_verify message later.
                                    main_cert_pub_key_algo = subject.pub_key_algo;
                                    const pub_key = subject.pubKey();
                                    if (pub_key.len > main_cert_pub_key_buf.len)
                                        return error.CertificatePublicKeyInvalid;
                                    @memcpy(main_cert_pub_key_buf[0..pub_key.len], pub_key);
                                    main_cert_pub_key_len = @intCast(pub_key.len);
                                } else {
                                    try prev_cert.verify(subject, now_sec);
                                }

                                if (ca_bundle.verify(subject, now_sec)) |_| {
                                    handshake_state = .trust_chain_established;
                                    break :cert;
                                } else |err| switch (err) {
                                    error.CertificateIssuerNotFound => {},
                                    else => |e| return e,
                                }

                                prev_cert = subject;
                                cert_index += 1;

                                try certs_decoder.ensure(2);
                                const total_ext_size = certs_decoder.decode(u16);
                                const all_extd = try certs_decoder.sub(total_ext_size);
                                _ = all_extd;
                            }
                        },
                        .certificate_verify => {
                            switch (handshake_state) {
                                .trust_chain_established => handshake_state = .finished,
                                .certificate => return error.TlsCertificateNotVerified,
                                else => return error.TlsUnexpectedMessage,
                            }

                            try hsd.ensure(4);
                            const scheme = hsd.decode(tls.SignatureScheme);
                            const sig_len = hsd.decode(u16);
                            try hsd.ensure(sig_len);
                            const encoded_sig = hsd.slice(sig_len);
                            const max_digest_len = 64;
                            var verify_buffer: [64 + 34 + max_digest_len]u8 =
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

                            switch (scheme) {
                                inline .ecdsa_secp256r1_sha256,
                                .ecdsa_secp384r1_sha384,
                                => |comptime_scheme| {
                                    if (main_cert_pub_key_algo != .X9_62_id_ecPublicKey)
                                        return error.TlsBadSignatureScheme;
                                    const Ecdsa = SchemeEcdsa(comptime_scheme);
                                    const sig = try Ecdsa.Signature.fromDer(encoded_sig);
                                    const key = try Ecdsa.PublicKey.fromSec1(main_cert_pub_key);
                                    try sig.verify(verify_bytes, key);
                                },
                                inline .rsa_pss_rsae_sha256,
                                .rsa_pss_rsae_sha384,
                                .rsa_pss_rsae_sha512,
                                => |comptime_scheme| {
                                    if (main_cert_pub_key_algo != .rsaEncryption)
                                        return error.TlsBadSignatureScheme;

                                    const Hash = SchemeHash(comptime_scheme);
                                    const rsa = Certificate.rsa;
                                    const components = try rsa.PublicKey.parseDer(main_cert_pub_key);
                                    const exponent = components.exponent;
                                    const modulus = components.modulus;
                                    switch (modulus.len) {
                                        inline 128, 256, 512 => |modulus_len| {
                                            const key = try rsa.PublicKey.fromBytes(exponent, modulus);
                                            const sig = rsa.PSSSignature.fromBytes(modulus_len, encoded_sig);
                                            try rsa.PSSSignature.verify(modulus_len, sig, verify_bytes, key, Hash);
                                        },
                                        else => {
                                            return error.TlsBadRsaSignatureBitCount;
                                        },
                                    }
                                },
                                inline .ed25519 => |comptime_scheme| {
                                    if (main_cert_pub_key_algo != .curveEd25519) return error.TlsBadSignatureScheme;
                                    const Eddsa = SchemeEddsa(comptime_scheme);
                                    if (encoded_sig.len != Eddsa.Signature.encoded_length) return error.InvalidEncoding;
                                    const sig = Eddsa.Signature.fromBytes(encoded_sig[0..Eddsa.Signature.encoded_length].*);
                                    if (main_cert_pub_key.len != Eddsa.PublicKey.encoded_length) return error.InvalidEncoding;
                                    const key = try Eddsa.PublicKey.fromBytes(main_cert_pub_key[0..Eddsa.PublicKey.encoded_length].*);
                                    try sig.verify(verify_bytes, key);
                                },
                                else => {
                                    return error.TlsBadSignatureScheme;
                                },
                            }
                        },
                        .finished => {
                            if (handshake_state != .finished) return error.TlsUnexpectedMessage;
                            // This message is to trick buggy proxies into behaving correctly.
                            const client_change_cipher_spec_msg = [_]u8{
                                @intFromEnum(tls.ContentType.change_cipher_spec),
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
                                        @intFromEnum(tls.HandshakeType.finished),
                                        0, 0, verify_data.len, // length
                                    } ++ verify_data ++ [1]u8{@intFromEnum(tls.ContentType.handshake)};

                                    const wrapped_len = out_cleartext.len + P.AEAD.tag_length;

                                    var finished_msg = [_]u8{
                                        @intFromEnum(tls.ContentType.application_data),
                                        0x03, 0x03, // legacy protocol version
                                        0, wrapped_len, // byte length of encrypted record
                                    } ++ @as([wrapped_len]u8, undefined);

                                    const ad = finished_msg[0..5];
                                    const ciphertext = finished_msg[5..][0..out_cleartext.len];
                                    const auth_tag = finished_msg[finished_msg.len - P.AEAD.tag_length ..];
                                    const nonce = p.client_handshake_iv;
                                    P.AEAD.encrypt(ciphertext, auth_tag, &out_cleartext, ad, nonce, p.client_handshake_key);

                                    const both_msgs = client_change_cipher_spec_msg ++ finished_msg;
                                    var both_msgs_vec = [_]std.posix.iovec_const{.{
                                        .base = &both_msgs,
                                        .len = both_msgs.len,
                                    }};
                                    try stream.writevAll(&both_msgs_vec);

                                    const client_secret = hkdfExpandLabel(P.Hkdf, p.master_secret, "c ap traffic", &handshake_hash, P.Hash.digest_length);
                                    const server_secret = hkdfExpandLabel(P.Hkdf, p.master_secret, "s ap traffic", &handshake_hash, P.Hash.digest_length);
                                    break :c @unionInit(tls.ApplicationCipher, @tagName(tag), .{
                                        .client_secret = client_secret,
                                        .server_secret = server_secret,
                                        .client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length),
                                        .server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length),
                                        .client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length),
                                        .server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length),
                                    });
                                },
                            };
                            const leftover = d.rest();
                            var client: Client = .{
                                .read_seq = 0,
                                .write_seq = 0,
                                .partial_cleartext_idx = 0,
                                .partial_ciphertext_idx = 0,
                                .partial_ciphertext_end = @intCast(leftover.len),
                                .received_close_notify = false,
                                .application_cipher = app_cipher,
                                .partially_read_buffer = undefined,
                            };
                            @memcpy(client.partially_read_buffer[0..leftover.len], leftover);
                            return client;
                        },
                        else => {
                            return error.TlsUnexpectedMessage;
                        },
                    }
                    if (ctd.eof()) break;
                }
            },
            else => {
                return error.TlsUnexpectedMessage;
            },
        }
    }
}

/// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
/// Returns the number of plaintext bytes sent, which may be fewer than `bytes.len`.
pub fn write(c: *Client, stream: anytype, bytes: []const u8) !usize {
    return writeEnd(c, stream, bytes, false);
}

/// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
pub fn writeAll(c: *Client, stream: anytype, bytes: []const u8) !void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try c.write(stream, bytes[index..]);
    }
}

/// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
/// If `end` is true, then this function additionally sends a `close_notify` alert,
/// which is necessary for the server to distinguish between a properly finished
/// TLS session, or a truncation attack.
pub fn writeAllEnd(c: *Client, stream: anytype, bytes: []const u8, end: bool) !void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try c.writeEnd(stream, bytes[index..], end);
    }
}

/// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
/// Returns the number of plaintext bytes sent, which may be fewer than `bytes.len`.
/// If `end` is true, then this function additionally sends a `close_notify` alert,
/// which is necessary for the server to distinguish between a properly finished
/// TLS session, or a truncation attack.
pub fn writeEnd(c: *Client, stream: anytype, bytes: []const u8, end: bool) !usize {
    var ciphertext_buf: [tls.max_ciphertext_record_len * 4]u8 = undefined;
    var iovecs_buf: [6]std.posix.iovec_const = undefined;
    var prepared = prepareCiphertextRecord(c, &iovecs_buf, &ciphertext_buf, bytes, .application_data);
    if (end) {
        prepared.iovec_end += prepareCiphertextRecord(
            c,
            iovecs_buf[prepared.iovec_end..],
            ciphertext_buf[prepared.ciphertext_end..],
            &tls.close_notify_alert,
            .alert,
        ).iovec_end;
    }

    const iovec_end = prepared.iovec_end;
    const overhead_len = prepared.overhead_len;

    // Ideally we would call writev exactly once here, however, we must ensure
    // that we don't return with a record partially written.
    var i: usize = 0;
    var total_amt: usize = 0;
    while (true) {
        var amt = try stream.writev(iovecs_buf[i..iovec_end]);
        while (amt >= iovecs_buf[i].len) {
            const encrypted_amt = iovecs_buf[i].len;
            total_amt += encrypted_amt - overhead_len;
            amt -= encrypted_amt;
            i += 1;
            // Rely on the property that iovecs delineate records, meaning that
            // if amt equals zero here, we have fortunately found ourselves
            // with a short read that aligns at the record boundary.
            if (i >= iovec_end) return total_amt;
            // We also cannot return on a vector boundary if the final close_notify is
            // not sent; otherwise the caller would not know to retry the call.
            if (amt == 0 and (!end or i < iovec_end - 1)) return total_amt;
        }
        iovecs_buf[i].base += amt;
        iovecs_buf[i].len -= amt;
    }
}

fn prepareCiphertextRecord(
    c: *Client,
    iovecs: []std.posix.iovec_const,
    ciphertext_buf: []u8,
    bytes: []const u8,
    inner_content_type: tls.ContentType,
) struct {
    iovec_end: usize,
    ciphertext_end: usize,
    /// How many bytes are taken up by overhead per record.
    overhead_len: usize,
} {
    // Due to the trailing inner content type byte in the ciphertext, we need
    // an additional buffer for storing the cleartext into before encrypting.
    var cleartext_buf: [max_ciphertext_len]u8 = undefined;
    var ciphertext_end: usize = 0;
    var iovec_end: usize = 0;
    var bytes_i: usize = 0;
    switch (c.application_cipher) {
        inline else => |*p| {
            const P = @TypeOf(p.*);
            const overhead_len = tls.record_header_len + P.AEAD.tag_length + 1;
            const close_notify_alert_reserved = tls.close_notify_alert.len + overhead_len;
            while (true) {
                const encrypted_content_len: u16 = @intCast(@min(
                    @min(bytes.len - bytes_i, tls.max_ciphertext_inner_record_len),
                    ciphertext_buf.len -|
                        (close_notify_alert_reserved + overhead_len + ciphertext_end),
                ));
                if (encrypted_content_len == 0) return .{
                    .iovec_end = iovec_end,
                    .ciphertext_end = ciphertext_end,
                    .overhead_len = overhead_len,
                };

                @memcpy(cleartext_buf[0..encrypted_content_len], bytes[bytes_i..][0..encrypted_content_len]);
                cleartext_buf[encrypted_content_len] = @intFromEnum(inner_content_type);
                bytes_i += encrypted_content_len;
                const ciphertext_len = encrypted_content_len + 1;
                const cleartext = cleartext_buf[0..ciphertext_len];

                const record_start = ciphertext_end;
                const ad = ciphertext_buf[ciphertext_end..][0..5];
                ad.* =
                    [_]u8{@intFromEnum(tls.ContentType.application_data)} ++
                    int2(@intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                    int2(ciphertext_len + P.AEAD.tag_length);
                ciphertext_end += ad.len;
                const ciphertext = ciphertext_buf[ciphertext_end..][0..ciphertext_len];
                ciphertext_end += ciphertext_len;
                const auth_tag = ciphertext_buf[ciphertext_end..][0..P.AEAD.tag_length];
                ciphertext_end += auth_tag.len;
                const nonce = if (builtin.zig_backend == .stage2_x86_64 and
                    P.AEAD.nonce_length > comptime std.simd.suggestVectorLength(u8) orelse 1)
                nonce: {
                    var nonce = p.client_iv;
                    const operand = std.mem.readInt(u64, nonce[nonce.len - 8 ..], .big);
                    std.mem.writeInt(u64, nonce[nonce.len - 8 ..], operand ^ c.write_seq, .big);
                    break :nonce nonce;
                } else nonce: {
                    const V = @Vector(P.AEAD.nonce_length, u8);
                    const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                    const operand: V = pad ++ @as([8]u8, @bitCast(big(c.write_seq)));
                    break :nonce @as(V, p.client_iv) ^ operand;
                };
                c.write_seq += 1; // TODO send key_update on overflow
                P.AEAD.encrypt(ciphertext, auth_tag, cleartext, ad, nonce, p.client_key);

                const record = ciphertext_buf[record_start..ciphertext_end];
                iovecs[iovec_end] = .{
                    .base = record.ptr,
                    .len = record.len,
                };
                iovec_end += 1;
            }
        },
    }
}

pub fn eof(c: Client) bool {
    return c.received_close_notify and
        c.partial_cleartext_idx >= c.partial_ciphertext_idx and
        c.partial_ciphertext_idx >= c.partial_ciphertext_end;
}

/// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
/// Returns the number of bytes read, calling the underlying read function the
/// minimal number of times until the buffer has at least `len` bytes filled.
/// If the number read is less than `len` it means the stream reached the end.
/// Reaching the end of the stream is not an error condition.
pub fn readAtLeast(c: *Client, stream: anytype, buffer: []u8, len: usize) !usize {
    var iovecs = [1]std.posix.iovec{.{ .base = buffer.ptr, .len = buffer.len }};
    return readvAtLeast(c, stream, &iovecs, len);
}

/// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
pub fn read(c: *Client, stream: anytype, buffer: []u8) !usize {
    return readAtLeast(c, stream, buffer, 1);
}

/// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
/// Returns the number of bytes read. If the number read is smaller than
/// `buffer.len`, it means the stream reached the end. Reaching the end of the
/// stream is not an error condition.
pub fn readAll(c: *Client, stream: anytype, buffer: []u8) !usize {
    return readAtLeast(c, stream, buffer, buffer.len);
}

/// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
/// Returns the number of bytes read. If the number read is less than the space
/// provided it means the stream reached the end. Reaching the end of the
/// stream is not an error condition.
/// The `iovecs` parameter is mutable because this function needs to mutate the fields in
/// order to handle partial reads from the underlying stream layer.
pub fn readv(c: *Client, stream: anytype, iovecs: []std.posix.iovec) !usize {
    return readvAtLeast(c, stream, iovecs, 1);
}

/// Receives TLS-encrypted data from `stream`, which must conform to `StreamInterface`.
/// Returns the number of bytes read, calling the underlying read function the
/// minimal number of times until the iovecs have at least `len` bytes filled.
/// If the number read is less than `len` it means the stream reached the end.
/// Reaching the end of the stream is not an error condition.
/// The `iovecs` parameter is mutable because this function needs to mutate the fields in
/// order to handle partial reads from the underlying stream layer.
pub fn readvAtLeast(c: *Client, stream: anytype, iovecs: []std.posix.iovec, len: usize) !usize {
    if (c.eof()) return 0;

    var off_i: usize = 0;
    var vec_i: usize = 0;
    while (true) {
        var amt = try c.readvAdvanced(stream, iovecs[vec_i..]);
        off_i += amt;
        if (c.eof() or off_i >= len) return off_i;
        while (amt >= iovecs[vec_i].len) {
            amt -= iovecs[vec_i].len;
            vec_i += 1;
        }
        iovecs[vec_i].base += amt;
        iovecs[vec_i].len -= amt;
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
pub fn readvAdvanced(c: *Client, stream: anytype, iovecs: []const std.posix.iovec) !usize {
    var vp: VecPut = .{ .iovecs = iovecs };

    // Give away the buffered cleartext we have, if any.
    const partial_cleartext = c.partially_read_buffer[c.partial_cleartext_idx..c.partial_ciphertext_idx];
    if (partial_cleartext.len > 0) {
        const amt: u15 = @intCast(vp.put(partial_cleartext));
        c.partial_cleartext_idx += amt;

        if (c.partial_cleartext_idx == c.partial_ciphertext_idx and
            c.partial_ciphertext_end == c.partial_ciphertext_idx)
        {
            // The buffer is now empty.
            c.partial_cleartext_idx = 0;
            c.partial_ciphertext_idx = 0;
            c.partial_ciphertext_end = 0;
        }

        if (c.received_close_notify) {
            c.partial_ciphertext_end = 0;
            assert(vp.total == amt);
            return amt;
        } else if (amt > 0) {
            // We don't need more data, so don't call read.
            assert(vp.total == amt);
            return amt;
        }
    }

    assert(!c.received_close_notify);

    // Ideally, this buffer would never be used. It is needed when `iovecs` are
    // too small to fit the cleartext, which may be as large as `max_ciphertext_len`.
    var cleartext_stack_buffer: [max_ciphertext_len]u8 = undefined;
    // Temporarily stores ciphertext before decrypting it and giving it to `iovecs`.
    var in_stack_buffer: [max_ciphertext_len * 4]u8 = undefined;
    // How many bytes left in the user's buffer.
    const free_size = vp.freeSize();
    // The amount of the user's buffer that we need to repurpose for storing
    // ciphertext. The end of the buffer will be used for such purposes.
    const ciphertext_buf_len = (free_size / 2) -| in_stack_buffer.len;
    // The amount of the user's buffer that will be used to give cleartext. The
    // beginning of the buffer will be used for such purposes.
    const cleartext_buf_len = free_size - ciphertext_buf_len;

    // Recoup `partially_read_buffer space`. This is necessary because it is assumed
    // below that `frag0` is big enough to hold at least one record.
    limitedOverlapCopy(c.partially_read_buffer[0..c.partial_ciphertext_end], c.partial_ciphertext_idx);
    c.partial_ciphertext_end -= c.partial_ciphertext_idx;
    c.partial_ciphertext_idx = 0;
    c.partial_cleartext_idx = 0;
    const first_iov = c.partially_read_buffer[c.partial_ciphertext_end..];

    var ask_iovecs_buf: [2]std.posix.iovec = .{
        .{
            .base = first_iov.ptr,
            .len = first_iov.len,
        },
        .{
            .base = &in_stack_buffer,
            .len = in_stack_buffer.len,
        },
    };

    // Cleartext capacity of output buffer, in records. Minimum one full record.
    const buf_cap = @max(cleartext_buf_len / max_ciphertext_len, 1);
    const wanted_read_len = buf_cap * (max_ciphertext_len + tls.record_header_len);
    const ask_len = @max(wanted_read_len, cleartext_stack_buffer.len) - c.partial_ciphertext_end;
    const ask_iovecs = limitVecs(&ask_iovecs_buf, ask_len);
    const actual_read_len = try stream.readv(ask_iovecs);
    if (actual_read_len == 0) {
        // This is either a truncation attack, a bug in the server, or an
        // intentional omission of the close_notify message due to truncation
        // detection handled above the TLS layer.
        if (c.allow_truncation_attacks) {
            c.received_close_notify = true;
        } else {
            return error.TlsConnectionTruncated;
        }
    }

    // There might be more bytes inside `in_stack_buffer` that need to be processed,
    // but at least frag0 will have one complete ciphertext record.
    const frag0_end = @min(c.partially_read_buffer.len, c.partial_ciphertext_end + actual_read_len);
    const frag0 = c.partially_read_buffer[c.partial_ciphertext_idx..frag0_end];
    var frag1 = in_stack_buffer[0..actual_read_len -| first_iov.len];
    // We need to decipher frag0 and frag1 but there may be a ciphertext record
    // straddling the boundary. We can handle this with two memcpy() calls to
    // assemble the straddling record in between handling the two sides.
    var frag = frag0;
    var in: usize = 0;
    while (true) {
        if (in == frag.len) {
            // Perfect split.
            if (frag.ptr == frag1.ptr) {
                c.partial_ciphertext_end = c.partial_ciphertext_idx;
                return vp.total;
            }
            frag = frag1;
            in = 0;
            continue;
        }

        if (in + tls.record_header_len > frag.len) {
            if (frag.ptr == frag1.ptr)
                return finishRead(c, frag, in, vp.total);

            const first = frag[in..];

            if (frag1.len < tls.record_header_len)
                return finishRead2(c, first, frag1, vp.total);

            // A record straddles the two fragments. Copy into the now-empty first fragment.
            const record_len_byte_0: u16 = straddleByte(frag, frag1, in + 3);
            const record_len_byte_1: u16 = straddleByte(frag, frag1, in + 4);
            const record_len = (record_len_byte_0 << 8) | record_len_byte_1;
            if (record_len > max_ciphertext_len) return error.TlsRecordOverflow;

            const full_record_len = record_len + tls.record_header_len;
            const second_len = full_record_len - first.len;
            if (frag1.len < second_len)
                return finishRead2(c, first, frag1, vp.total);

            limitedOverlapCopy(frag, in);
            @memcpy(frag[first.len..][0..second_len], frag1[0..second_len]);
            frag = frag[0..full_record_len];
            frag1 = frag1[second_len..];
            in = 0;
            continue;
        }
        const ct: tls.ContentType = @enumFromInt(frag[in]);
        in += 1;
        const legacy_version = mem.readInt(u16, frag[in..][0..2], .big);
        in += 2;
        _ = legacy_version;
        const record_len = mem.readInt(u16, frag[in..][0..2], .big);
        if (record_len > max_ciphertext_len) return error.TlsRecordOverflow;
        in += 2;
        const end = in + record_len;
        if (end > frag.len) {
            // We need the record header on the next iteration of the loop.
            in -= tls.record_header_len;

            if (frag.ptr == frag1.ptr)
                return finishRead(c, frag, in, vp.total);

            // A record straddles the two fragments. Copy into the now-empty first fragment.
            const first = frag[in..];
            const full_record_len = record_len + tls.record_header_len;
            const second_len = full_record_len - first.len;
            if (frag1.len < second_len)
                return finishRead2(c, first, frag1, vp.total);

            limitedOverlapCopy(frag, in);
            @memcpy(frag[first.len..][0..second_len], frag1[0..second_len]);
            frag = frag[0..full_record_len];
            frag1 = frag1[second_len..];
            in = 0;
            continue;
        }
        switch (ct) {
            .alert => {
                if (in + 2 > frag.len) return error.TlsDecodeError;
                const level: tls.AlertLevel = @enumFromInt(frag[in]);
                const desc: tls.AlertDescription = @enumFromInt(frag[in + 1]);
                _ = level;

                try desc.toError();
                // TODO: handle server-side closures
                return error.TlsUnexpectedMessage;
            },
            .application_data => {
                const cleartext = switch (c.application_cipher) {
                    inline else => |*p| c: {
                        const P = @TypeOf(p.*);
                        const ad = frag[in - 5 ..][0..5];
                        const ciphertext_len = record_len - P.AEAD.tag_length;
                        const ciphertext = frag[in..][0..ciphertext_len];
                        in += ciphertext_len;
                        const auth_tag = frag[in..][0..P.AEAD.tag_length].*;
                        const nonce = if (builtin.zig_backend == .stage2_x86_64 and
                            P.AEAD.nonce_length > comptime std.simd.suggestVectorLength(u8) orelse 1)
                        nonce: {
                            var nonce = p.server_iv;
                            const operand = std.mem.readInt(u64, nonce[nonce.len - 8 ..], .big);
                            std.mem.writeInt(u64, nonce[nonce.len - 8 ..], operand ^ c.read_seq, .big);
                            break :nonce nonce;
                        } else nonce: {
                            const V = @Vector(P.AEAD.nonce_length, u8);
                            const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                            const operand: V = pad ++ @as([8]u8, @bitCast(big(c.read_seq)));
                            break :nonce @as(V, p.server_iv) ^ operand;
                        };
                        const out_buf = vp.peek();
                        const cleartext_buf = if (ciphertext.len <= out_buf.len)
                            out_buf
                        else
                            &cleartext_stack_buffer;
                        const cleartext = cleartext_buf[0..ciphertext.len];
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag, ad, nonce, p.server_key) catch
                            return error.TlsBadRecordMac;
                        break :c mem.trimRight(u8, cleartext, "\x00");
                    },
                };

                c.read_seq = try std.math.add(u64, c.read_seq, 1);

                const inner_ct: tls.ContentType = @enumFromInt(cleartext[cleartext.len - 1]);
                switch (inner_ct) {
                    .alert => {
                        const level: tls.AlertLevel = @enumFromInt(cleartext[0]);
                        const desc: tls.AlertDescription = @enumFromInt(cleartext[1]);
                        if (desc == .close_notify) {
                            c.received_close_notify = true;
                            c.partial_ciphertext_end = c.partial_ciphertext_idx;
                            return vp.total;
                        }
                        _ = level;

                        try desc.toError();
                        // TODO: handle server-side closures
                        return error.TlsUnexpectedMessage;
                    },
                    .handshake => {
                        var ct_i: usize = 0;
                        while (true) {
                            const handshake_type: tls.HandshakeType = @enumFromInt(cleartext[ct_i]);
                            ct_i += 1;
                            const handshake_len = mem.readInt(u24, cleartext[ct_i..][0..3], .big);
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

                                    switch (@as(tls.KeyUpdateRequest, @enumFromInt(handshake[0]))) {
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
                        if (cleartext.ptr == &cleartext_stack_buffer) {
                            // Stack buffer was used, so we must copy to the output buffer.
                            const msg = cleartext[0 .. cleartext.len - 1];
                            if (c.partial_ciphertext_idx > c.partial_cleartext_idx) {
                                // We have already run out of room in iovecs. Continue
                                // appending to `partially_read_buffer`.
                                @memcpy(
                                    c.partially_read_buffer[c.partial_ciphertext_idx..][0..msg.len],
                                    msg,
                                );
                                c.partial_ciphertext_idx = @intCast(c.partial_ciphertext_idx + msg.len);
                            } else {
                                const amt = vp.put(msg);
                                if (amt < msg.len) {
                                    const rest = msg[amt..];
                                    c.partial_cleartext_idx = 0;
                                    c.partial_ciphertext_idx = @intCast(rest.len);
                                    @memcpy(c.partially_read_buffer[0..rest.len], rest);
                                }
                            }
                        } else {
                            // Output buffer was used directly which means no
                            // memory copying needs to occur, and we can move
                            // on to the next ciphertext record.
                            vp.next(cleartext.len - 1);
                        }
                    },
                    else => {
                        return error.TlsUnexpectedMessage;
                    },
                }
            },
            else => {
                return error.TlsUnexpectedMessage;
            },
        }
        in = end;
    }
}

fn finishRead(c: *Client, frag: []const u8, in: usize, out: usize) usize {
    const saved_buf = frag[in..];
    if (c.partial_ciphertext_idx > c.partial_cleartext_idx) {
        // There is cleartext at the beginning already which we need to preserve.
        c.partial_ciphertext_end = @intCast(c.partial_ciphertext_idx + saved_buf.len);
        @memcpy(c.partially_read_buffer[c.partial_ciphertext_idx..][0..saved_buf.len], saved_buf);
    } else {
        c.partial_cleartext_idx = 0;
        c.partial_ciphertext_idx = 0;
        c.partial_ciphertext_end = @intCast(saved_buf.len);
        @memcpy(c.partially_read_buffer[0..saved_buf.len], saved_buf);
    }
    return out;
}

/// Note that `first` usually overlaps with `c.partially_read_buffer`.
fn finishRead2(c: *Client, first: []const u8, frag1: []const u8, out: usize) usize {
    if (c.partial_ciphertext_idx > c.partial_cleartext_idx) {
        // There is cleartext at the beginning already which we need to preserve.
        c.partial_ciphertext_end = @intCast(c.partial_ciphertext_idx + first.len + frag1.len);
        // TODO: eliminate this call to copyForwards
        std.mem.copyForwards(u8, c.partially_read_buffer[c.partial_ciphertext_idx..][0..first.len], first);
        @memcpy(c.partially_read_buffer[c.partial_ciphertext_idx + first.len ..][0..frag1.len], frag1);
    } else {
        c.partial_cleartext_idx = 0;
        c.partial_ciphertext_idx = 0;
        c.partial_ciphertext_end = @intCast(first.len + frag1.len);
        // TODO: eliminate this call to copyForwards
        std.mem.copyForwards(u8, c.partially_read_buffer[0..first.len], first);
        @memcpy(c.partially_read_buffer[first.len..][0..frag1.len], frag1);
    }
    return out;
}

fn limitedOverlapCopy(frag: []u8, in: usize) void {
    const first = frag[in..];
    if (first.len <= in) {
        // A single, non-overlapping memcpy suffices.
        @memcpy(frag[0..first.len], first);
    } else {
        // One memcpy call would overlap, so just do this instead.
        std.mem.copyForwards(u8, frag, first);
    }
}

fn straddleByte(s1: []const u8, s2: []const u8, index: usize) u8 {
    if (index < s1.len) {
        return s1[index];
    } else {
        return s2[index - s1.len];
    }
}

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

inline fn big(x: anytype) @TypeOf(x) {
    return switch (native_endian) {
        .big => x,
        .little => @byteSwap(x),
    };
}

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

/// Abstraction for sending multiple byte buffers to a slice of iovecs.
const VecPut = struct {
    iovecs: []const std.posix.iovec,
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
            const dest = v.base[vp.off..v.len];
            const src = bytes[bytes_i..][0..@min(dest.len, bytes.len - bytes_i)];
            @memcpy(dest[0..src.len], src);
            bytes_i += src.len;
            vp.off += src.len;
            if (vp.off >= v.len) {
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
        return v.base[vp.off..v.len];
    }

    // After writing to the result of peek(), one can call next() to
    // advance the cursor.
    fn next(vp: *VecPut, len: usize) void {
        vp.total += len;
        vp.off += len;
        if (vp.off >= vp.iovecs[vp.idx].len) {
            vp.off = 0;
            vp.idx += 1;
        }
    }

    fn freeSize(vp: VecPut) usize {
        if (vp.idx >= vp.iovecs.len) return 0;
        var total: usize = 0;
        total += vp.iovecs[vp.idx].len - vp.off;
        if (vp.idx + 1 >= vp.iovecs.len) return total;
        for (vp.iovecs[vp.idx + 1 ..]) |v| total += v.len;
        return total;
    }
};

/// Limit iovecs to a specific byte size.
fn limitVecs(iovecs: []std.posix.iovec, len: usize) []std.posix.iovec {
    var bytes_left: usize = len;
    for (iovecs, 0..) |*iovec, vec_i| {
        if (bytes_left <= iovec.len) {
            iovec.len = bytes_left;
            return iovecs[0 .. vec_i + 1];
        }
        bytes_left -= iovec.len;
    }
    return iovecs;
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
const cipher_suites = if (crypto.core.aes.has_hardware_support)
    enum_array(tls.CipherSuite, &.{
        .AEGIS_128L_SHA256,
        .AEGIS_256_SHA512,
        .AES_128_GCM_SHA256,
        .AES_256_GCM_SHA384,
        .CHACHA20_POLY1305_SHA256,
    })
else
    enum_array(tls.CipherSuite, &.{
        .CHACHA20_POLY1305_SHA256,
        .AEGIS_128L_SHA256,
        .AEGIS_256_SHA512,
        .AES_128_GCM_SHA256,
        .AES_256_GCM_SHA384,
    });

test {
    _ = StreamInterface;
}

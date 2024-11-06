//! Plaintext:
//! * type: ContentType
//! * legacy_record_version: u16 = 0x0303,
//! * length: u16,
//!   - The length (in bytes) of the following TLSPlaintext.fragment.  The
//!     length MUST NOT exceed 2^14 bytes.
//! * fragment: opaque
//!   - the data being transmitted
//!
//! Ciphertext
//! * ContentType opaque_type = application_data; /* 23 */
//! * ProtocolVersion legacy_record_version = 0x0303; /* TLS v1.2 */
//! * uint16 length;
//! * opaque encrypted_record[TLSCiphertext.length];
//!
//! Handshake:
//! * type: HandshakeType
//! * length: u24
//! * data: opaque
//!
//! ServerHello:
//! * ProtocolVersion legacy_version = 0x0303;
//! * Random random;
//! * opaque legacy_session_id_echo<0..32>;
//! * CipherSuite cipher_suite;
//! * uint8 legacy_compression_method = 0;
//! * Extension extensions<6..2^16-1>;
//!
//! Extension:
//! * ExtensionType extension_type;
//! * opaque extension_data<0..2^16-1>;

const std = @import("../std.zig");
const Tls = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;

pub const Client = @import("tls/Client.zig");

pub const record_header_len = 5;
pub const max_ciphertext_inner_record_len = 1 << 14;
pub const max_ciphertext_len = max_ciphertext_inner_record_len + 256;
pub const max_ciphertext_record_len = max_ciphertext_len + record_header_len;
pub const hello_retry_request_sequence = [32]u8{
    0xCF, 0x21, 0xAD, 0x74, 0xE5, 0x9A, 0x61, 0x11, 0xBE, 0x1D, 0x8C, 0x02, 0x1E, 0x65, 0xB8, 0x91,
    0xC2, 0xA2, 0x11, 0x16, 0x7A, 0xBB, 0x8C, 0x5E, 0x07, 0x9E, 0x09, 0xE2, 0xC8, 0xA8, 0x33, 0x9C,
};

pub const close_notify_alert = [_]u8{
    @intFromEnum(AlertLevel.warning),
    @intFromEnum(AlertDescription.close_notify),
};

pub const ProtocolVersion = enum(u16) {
    tls_1_0 = 0x0301,
    tls_1_1 = 0x0302,
    tls_1_2 = 0x0303,
    tls_1_3 = 0x0304,
    _,
};

pub const ContentType = enum(u8) {
    invalid = 0,
    change_cipher_spec = 20,
    alert = 21,
    handshake = 22,
    application_data = 23,
    _,
};

pub const HandshakeType = enum(u8) {
    hello_request = 0,
    client_hello = 1,
    server_hello = 2,
    new_session_ticket = 4,
    end_of_early_data = 5,
    encrypted_extensions = 8,
    certificate = 11,
    server_key_exchange = 12,
    certificate_request = 13,
    server_hello_done = 14,
    certificate_verify = 15,
    client_key_exchange = 16,
    finished = 20,
    key_update = 24,
    message_hash = 254,
    _,
};

pub const ExtensionType = enum(u16) {
    /// RFC 6066
    server_name = 0,
    /// RFC 6066
    max_fragment_length = 1,
    /// RFC 6066
    status_request = 5,
    /// RFC 8422, 7919
    supported_groups = 10,
    /// RFC 8446
    signature_algorithms = 13,
    /// RFC 5764
    use_srtp = 14,
    /// RFC 6520
    heartbeat = 15,
    /// RFC 7301
    application_layer_protocol_negotiation = 16,
    /// RFC 6962
    signed_certificate_timestamp = 18,
    /// RFC 7250
    client_certificate_type = 19,
    /// RFC 7250
    server_certificate_type = 20,
    /// RFC 7685
    padding = 21,
    /// RFC 8446
    pre_shared_key = 41,
    /// RFC 8446
    early_data = 42,
    /// RFC 8446
    supported_versions = 43,
    /// RFC 8446
    cookie = 44,
    /// RFC 8446
    psk_key_exchange_modes = 45,
    /// RFC 8446
    certificate_authorities = 47,
    /// RFC 8446
    oid_filters = 48,
    /// RFC 8446
    post_handshake_auth = 49,
    /// RFC 8446
    signature_algorithms_cert = 50,
    /// RFC 8446
    key_share = 51,

    _,
};

pub const AlertLevel = enum(u8) {
    warning = 1,
    fatal = 2,
    _,
};

pub const AlertDescription = enum(u8) {
    pub const Error = error{
        TlsAlertUnexpectedMessage,
        TlsAlertBadRecordMac,
        TlsAlertRecordOverflow,
        TlsAlertHandshakeFailure,
        TlsAlertBadCertificate,
        TlsAlertUnsupportedCertificate,
        TlsAlertCertificateRevoked,
        TlsAlertCertificateExpired,
        TlsAlertCertificateUnknown,
        TlsAlertIllegalParameter,
        TlsAlertUnknownCa,
        TlsAlertAccessDenied,
        TlsAlertDecodeError,
        TlsAlertDecryptError,
        TlsAlertProtocolVersion,
        TlsAlertInsufficientSecurity,
        TlsAlertInternalError,
        TlsAlertInappropriateFallback,
        TlsAlertMissingExtension,
        TlsAlertUnsupportedExtension,
        TlsAlertUnrecognizedName,
        TlsAlertBadCertificateStatusResponse,
        TlsAlertUnknownPskIdentity,
        TlsAlertCertificateRequired,
        TlsAlertNoApplicationProtocol,
        TlsAlertUnknown,
    };

    close_notify = 0,
    unexpected_message = 10,
    bad_record_mac = 20,
    record_overflow = 22,
    handshake_failure = 40,
    bad_certificate = 42,
    unsupported_certificate = 43,
    certificate_revoked = 44,
    certificate_expired = 45,
    certificate_unknown = 46,
    illegal_parameter = 47,
    unknown_ca = 48,
    access_denied = 49,
    decode_error = 50,
    decrypt_error = 51,
    protocol_version = 70,
    insufficient_security = 71,
    internal_error = 80,
    inappropriate_fallback = 86,
    user_canceled = 90,
    missing_extension = 109,
    unsupported_extension = 110,
    unrecognized_name = 112,
    bad_certificate_status_response = 113,
    unknown_psk_identity = 115,
    certificate_required = 116,
    no_application_protocol = 120,
    _,

    pub fn toError(alert: AlertDescription) Error!void {
        switch (alert) {
            .close_notify => {}, // not an error
            .unexpected_message => return error.TlsAlertUnexpectedMessage,
            .bad_record_mac => return error.TlsAlertBadRecordMac,
            .record_overflow => return error.TlsAlertRecordOverflow,
            .handshake_failure => return error.TlsAlertHandshakeFailure,
            .bad_certificate => return error.TlsAlertBadCertificate,
            .unsupported_certificate => return error.TlsAlertUnsupportedCertificate,
            .certificate_revoked => return error.TlsAlertCertificateRevoked,
            .certificate_expired => return error.TlsAlertCertificateExpired,
            .certificate_unknown => return error.TlsAlertCertificateUnknown,
            .illegal_parameter => return error.TlsAlertIllegalParameter,
            .unknown_ca => return error.TlsAlertUnknownCa,
            .access_denied => return error.TlsAlertAccessDenied,
            .decode_error => return error.TlsAlertDecodeError,
            .decrypt_error => return error.TlsAlertDecryptError,
            .protocol_version => return error.TlsAlertProtocolVersion,
            .insufficient_security => return error.TlsAlertInsufficientSecurity,
            .internal_error => return error.TlsAlertInternalError,
            .inappropriate_fallback => return error.TlsAlertInappropriateFallback,
            .user_canceled => {}, // not an error
            .missing_extension => return error.TlsAlertMissingExtension,
            .unsupported_extension => return error.TlsAlertUnsupportedExtension,
            .unrecognized_name => return error.TlsAlertUnrecognizedName,
            .bad_certificate_status_response => return error.TlsAlertBadCertificateStatusResponse,
            .unknown_psk_identity => return error.TlsAlertUnknownPskIdentity,
            .certificate_required => return error.TlsAlertCertificateRequired,
            .no_application_protocol => return error.TlsAlertNoApplicationProtocol,
            _ => return error.TlsAlertUnknown,
        }
    }
};

pub const SignatureScheme = enum(u16) {
    // RSASSA-PKCS1-v1_5 algorithms
    rsa_pkcs1_sha256 = 0x0401,
    rsa_pkcs1_sha384 = 0x0501,
    rsa_pkcs1_sha512 = 0x0601,

    // ECDSA algorithms
    ecdsa_secp256r1_sha256 = 0x0403,
    ecdsa_secp384r1_sha384 = 0x0503,
    ecdsa_secp521r1_sha512 = 0x0603,

    // RSASSA-PSS algorithms with public key OID rsaEncryption
    rsa_pss_rsae_sha256 = 0x0804,
    rsa_pss_rsae_sha384 = 0x0805,
    rsa_pss_rsae_sha512 = 0x0806,

    // EdDSA algorithms
    ed25519 = 0x0807,
    ed448 = 0x0808,

    // RSASSA-PSS algorithms with public key OID RSASSA-PSS
    rsa_pss_pss_sha256 = 0x0809,
    rsa_pss_pss_sha384 = 0x080a,
    rsa_pss_pss_sha512 = 0x080b,

    // Legacy algorithms
    rsa_pkcs1_sha1 = 0x0201,
    ecdsa_sha1 = 0x0203,

    ecdsa_brainpoolP256r1tls13_sha256 = 0x081a,
    ecdsa_brainpoolP384r1tls13_sha384 = 0x081b,
    ecdsa_brainpoolP512r1tls13_sha512 = 0x081c,

    rsa_sha224 = 0x0301,
    dsa_sha224 = 0x0302,
    ecdsa_sha224 = 0x0303,
    dsa_sha256 = 0x0402,
    dsa_sha384 = 0x0502,
    dsa_sha512 = 0x0602,

    _,
};

pub const NamedGroup = enum(u16) {
    // Elliptic Curve Groups (ECDHE)
    secp256r1 = 0x0017,
    secp384r1 = 0x0018,
    secp521r1 = 0x0019,
    x25519 = 0x001D,
    x448 = 0x001E,

    // Finite Field Groups (DHE)
    ffdhe2048 = 0x0100,
    ffdhe3072 = 0x0101,
    ffdhe4096 = 0x0102,
    ffdhe6144 = 0x0103,
    ffdhe8192 = 0x0104,

    // Hybrid post-quantum key agreements
    secp256r1_ml_kem256 = 0x11EB,
    x25519_ml_kem768 = 0x11EC,

    _,
};

pub const PskKeyExchangeMode = enum(u8) {
    psk_ke = 0,
    psk_dhe_ke = 1,
    _,
};

pub const CipherSuite = enum(u16) {
    RSA_WITH_AES_128_CBC_SHA = 0x002F,
    DHE_RSA_WITH_AES_128_CBC_SHA = 0x0033,
    RSA_WITH_AES_256_CBC_SHA = 0x0035,
    DHE_RSA_WITH_AES_256_CBC_SHA = 0x0039,
    RSA_WITH_AES_128_CBC_SHA256 = 0x003C,
    RSA_WITH_AES_256_CBC_SHA256 = 0x003D,
    DHE_RSA_WITH_AES_128_CBC_SHA256 = 0x0067,
    DHE_RSA_WITH_AES_256_CBC_SHA256 = 0x006B,
    RSA_WITH_AES_128_GCM_SHA256 = 0x009C,
    RSA_WITH_AES_256_GCM_SHA384 = 0x009D,
    DHE_RSA_WITH_AES_128_GCM_SHA256 = 0x009E,
    DHE_RSA_WITH_AES_256_GCM_SHA384 = 0x009F,
    EMPTY_RENEGOTIATION_INFO_SCSV = 0x00FF,

    AES_128_GCM_SHA256 = 0x1301,
    AES_256_GCM_SHA384 = 0x1302,
    CHACHA20_POLY1305_SHA256 = 0x1303,
    AES_128_CCM_SHA256 = 0x1304,
    AES_128_CCM_8_SHA256 = 0x1305,
    AEGIS_256_SHA512 = 0x1306,
    AEGIS_128L_SHA256 = 0x1307,

    ECDHE_ECDSA_WITH_AES_128_CBC_SHA = 0xC009,
    ECDHE_ECDSA_WITH_AES_256_CBC_SHA = 0xC00A,
    ECDHE_RSA_WITH_AES_128_CBC_SHA = 0xC013,
    ECDHE_RSA_WITH_AES_256_CBC_SHA = 0xC014,
    ECDHE_ECDSA_WITH_AES_128_CBC_SHA256 = 0xC023,
    ECDHE_ECDSA_WITH_AES_256_CBC_SHA384 = 0xC024,
    ECDHE_RSA_WITH_AES_128_CBC_SHA256 = 0xC027,
    ECDHE_RSA_WITH_AES_256_CBC_SHA384 = 0xC028,
    ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 = 0xC02B,
    ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 = 0xC02C,
    ECDHE_RSA_WITH_AES_128_GCM_SHA256 = 0xC02F,
    ECDHE_RSA_WITH_AES_256_GCM_SHA384 = 0xC030,

    ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 = 0xCCA8,
    ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 = 0xCCA9,
    DHE_RSA_WITH_CHACHA20_POLY1305_SHA256 = 0xCCAA,

    _,

    pub const With = enum {
        AES_128_CBC_SHA,
        AES_256_CBC_SHA,
        AES_128_CBC_SHA256,
        AES_256_CBC_SHA256,
        AES_256_CBC_SHA384,

        AES_128_GCM_SHA256,
        AES_256_GCM_SHA384,

        CHACHA20_POLY1305_SHA256,

        AES_128_CCM_SHA256,
        AES_128_CCM_8_SHA256,

        AEGIS_256_SHA512,
        AEGIS_128L_SHA256,
    };

    pub fn with(cipher_suite: CipherSuite) With {
        return switch (cipher_suite) {
            .RSA_WITH_AES_128_CBC_SHA,
            .DHE_RSA_WITH_AES_128_CBC_SHA,
            .ECDHE_ECDSA_WITH_AES_128_CBC_SHA,
            .ECDHE_RSA_WITH_AES_128_CBC_SHA,
            => .AES_128_CBC_SHA,
            .RSA_WITH_AES_256_CBC_SHA,
            .DHE_RSA_WITH_AES_256_CBC_SHA,
            .ECDHE_ECDSA_WITH_AES_256_CBC_SHA,
            .ECDHE_RSA_WITH_AES_256_CBC_SHA,
            => .AES_256_CBC_SHA,
            .RSA_WITH_AES_128_CBC_SHA256,
            .DHE_RSA_WITH_AES_128_CBC_SHA256,
            .ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,
            .ECDHE_RSA_WITH_AES_128_CBC_SHA256,
            => .AES_128_CBC_SHA256,
            .RSA_WITH_AES_256_CBC_SHA256,
            .DHE_RSA_WITH_AES_256_CBC_SHA256,
            => .AES_256_CBC_SHA256,
            .ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,
            .ECDHE_RSA_WITH_AES_256_CBC_SHA384,
            => .AES_256_CBC_SHA384,

            .RSA_WITH_AES_128_GCM_SHA256,
            .DHE_RSA_WITH_AES_128_GCM_SHA256,
            .AES_128_GCM_SHA256,
            .ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
            .ECDHE_RSA_WITH_AES_128_GCM_SHA256,
            => .AES_128_GCM_SHA256,
            .RSA_WITH_AES_256_GCM_SHA384,
            .DHE_RSA_WITH_AES_256_GCM_SHA384,
            .AES_256_GCM_SHA384,
            .ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
            .ECDHE_RSA_WITH_AES_256_GCM_SHA384,
            => .AES_256_GCM_SHA384,

            .CHACHA20_POLY1305_SHA256,
            .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
            .ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
            .DHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
            => .CHACHA20_POLY1305_SHA256,

            .AES_128_CCM_SHA256 => .AES_128_CCM_SHA256,
            .AES_128_CCM_8_SHA256 => .AES_128_CCM_8_SHA256,

            .AEGIS_256_SHA512 => .AEGIS_256_SHA512,
            .AEGIS_128L_SHA256 => .AEGIS_128L_SHA256,

            .EMPTY_RENEGOTIATION_INFO_SCSV => unreachable,
            _ => unreachable,
        };
    }
};

pub const CompressionMethod = enum(u8) {
    null = 0,
    _,
};

pub const CertificateType = enum(u8) {
    X509 = 0,
    RawPublicKey = 2,
    _,
};

pub const KeyUpdateRequest = enum(u8) {
    update_not_requested = 0,
    update_requested = 1,
    _,
};

pub const ChangeCipherSpecType = enum(u8) {
    change_cipher_spec = 1,
    _,
};

pub fn HandshakeCipherT(comptime AeadType: type, comptime HashType: type, comptime explicit_iv_length: comptime_int) type {
    return struct {
        pub const A = ApplicationCipherT(AeadType, HashType, explicit_iv_length);

        transcript_hash: A.Hash,
        version: union {
            tls_1_2: struct {
                expected_server_verify_data: [A.verify_data_length]u8,
                app_cipher: A.Tls_1_2,
            },
            tls_1_3: struct {
                handshake_secret: [A.Hkdf.prk_length]u8,
                master_secret: [A.Hkdf.prk_length]u8,
                client_handshake_key: [A.AEAD.key_length]u8,
                server_handshake_key: [A.AEAD.key_length]u8,
                client_finished_key: [A.Hmac.key_length]u8,
                server_finished_key: [A.Hmac.key_length]u8,
                client_handshake_iv: [A.AEAD.nonce_length]u8,
                server_handshake_iv: [A.AEAD.nonce_length]u8,
            },
        },
    };
}

pub const HandshakeCipher = union(enum) {
    AES_128_GCM_SHA256: HandshakeCipherT(crypto.aead.aes_gcm.Aes128Gcm, crypto.hash.sha2.Sha256, 8),
    AES_256_GCM_SHA384: HandshakeCipherT(crypto.aead.aes_gcm.Aes256Gcm, crypto.hash.sha2.Sha384, 8),
    CHACHA20_POLY1305_SHA256: HandshakeCipherT(crypto.aead.chacha_poly.ChaCha20Poly1305, crypto.hash.sha2.Sha256, 0),
    AEGIS_256_SHA512: HandshakeCipherT(crypto.aead.aegis.Aegis256, crypto.hash.sha2.Sha512, 0),
    AEGIS_128L_SHA256: HandshakeCipherT(crypto.aead.aegis.Aegis128L, crypto.hash.sha2.Sha256, 0),
};

pub fn ApplicationCipherT(comptime AeadType: type, comptime HashType: type, comptime explicit_iv_length: comptime_int) type {
    return union {
        pub const AEAD = AeadType;
        pub const Hash = HashType;
        pub const Hmac = crypto.auth.hmac.Hmac(Hash);
        pub const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        pub const enc_key_length = AEAD.key_length;
        pub const fixed_iv_length = AEAD.nonce_length - explicit_iv_length;
        pub const record_iv_length = explicit_iv_length;
        pub const mac_length = AEAD.tag_length;
        pub const mac_key_length = Hmac.key_length_min;
        pub const verify_data_length = 12;

        tls_1_2: Tls_1_2,
        tls_1_3: Tls_1_3,

        pub const Tls_1_2 = extern struct {
            client_write_MAC_key: [mac_key_length]u8,
            server_write_MAC_key: [mac_key_length]u8,
            client_write_key: [enc_key_length]u8,
            server_write_key: [enc_key_length]u8,
            client_write_IV: [fixed_iv_length]u8,
            server_write_IV: [fixed_iv_length]u8,
            // non-standard entropy
            client_salt: [record_iv_length]u8,
        };

        pub const Tls_1_3 = struct {
            client_secret: [Hash.digest_length]u8,
            server_secret: [Hash.digest_length]u8,
            client_key: [AEAD.key_length]u8,
            server_key: [AEAD.key_length]u8,
            client_iv: [AEAD.nonce_length]u8,
            server_iv: [AEAD.nonce_length]u8,
        };
    };
}

/// Encryption parameters for application traffic.
pub const ApplicationCipher = union(enum) {
    AES_128_GCM_SHA256: ApplicationCipherT(crypto.aead.aes_gcm.Aes128Gcm, crypto.hash.sha2.Sha256, 8),
    AES_256_GCM_SHA384: ApplicationCipherT(crypto.aead.aes_gcm.Aes256Gcm, crypto.hash.sha2.Sha384, 8),
    CHACHA20_POLY1305_SHA256: ApplicationCipherT(crypto.aead.chacha_poly.ChaCha20Poly1305, crypto.hash.sha2.Sha256, 0),
    AEGIS_256_SHA512: ApplicationCipherT(crypto.aead.aegis.Aegis256, crypto.hash.sha2.Sha512, 0),
    AEGIS_128L_SHA256: ApplicationCipherT(crypto.aead.aegis.Aegis128L, crypto.hash.sha2.Sha256, 0),
};

pub fn hmacExpandLabel(
    comptime Hmac: type,
    secret: []const u8,
    label_then_seed: []const []const u8,
    comptime len: usize,
) [len]u8 {
    const initial_hmac: Hmac = .init(secret);
    var a: [Hmac.mac_length]u8 = undefined;
    var result: [std.mem.alignForwardAnyAlign(usize, len, Hmac.mac_length)]u8 = undefined;
    var index: usize = 0;
    while (index < result.len) : (index += Hmac.mac_length) {
        var a_hmac = initial_hmac;
        if (index > 0) a_hmac.update(&a) else for (label_then_seed) |part| a_hmac.update(part);
        a_hmac.final(&a);

        var result_hmac = initial_hmac;
        result_hmac.update(&a);
        for (label_then_seed) |part| result_hmac.update(part);
        result_hmac.final(result[index..][0..Hmac.mac_length]);
    }
    return result[0..len].*;
}

pub fn hkdfExpandLabel(
    comptime Hkdf: type,
    key: [Hkdf.prk_length]u8,
    label: []const u8,
    context: []const u8,
    comptime len: usize,
) [len]u8 {
    const max_label_len = 255;
    const max_context_len = 255;
    const tls13 = "tls13 ";
    var buf: [2 + 1 + tls13.len + max_label_len + 1 + max_context_len]u8 = undefined;
    mem.writeInt(u16, buf[0..2], len, .big);
    buf[2] = @as(u8, @intCast(tls13.len + label.len));
    buf[3..][0..tls13.len].* = tls13.*;
    var i: usize = 3 + tls13.len;
    @memcpy(buf[i..][0..label.len], label);
    i += label.len;
    buf[i] = @as(u8, @intCast(context.len));
    i += 1;
    @memcpy(buf[i..][0..context.len], context);
    i += context.len;

    var result: [len]u8 = undefined;
    Hkdf.expand(&result, buf[0..i], key);
    return result;
}

pub fn emptyHash(comptime Hash: type) [Hash.digest_length]u8 {
    var result: [Hash.digest_length]u8 = undefined;
    Hash.hash(&.{}, &result, .{});
    return result;
}

pub fn hmac(comptime Hmac: type, message: []const u8, key: [Hmac.key_length]u8) [Hmac.mac_length]u8 {
    var result: [Hmac.mac_length]u8 = undefined;
    Hmac.create(&result, message, &key);
    return result;
}

pub inline fn extension(et: ExtensionType, bytes: anytype) [2 + 2 + bytes.len]u8 {
    return int(u16, @intFromEnum(et)) ++ array(u16, u8, bytes);
}

pub inline fn array(
    comptime Len: type,
    comptime Elem: type,
    elems: anytype,
) [@divExact(@bitSizeOf(Len), 8) + @divExact(@bitSizeOf(Elem), 8) * elems.len]u8 {
    const len_size = @divExact(@bitSizeOf(Len), 8);
    const elem_size = @divExact(@bitSizeOf(Elem), 8);
    var arr: [len_size + elem_size * elems.len]u8 = undefined;
    std.mem.writeInt(Len, arr[0..len_size], @intCast(elem_size * elems.len), .big);
    const ElemInt = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @bitSizeOf(Elem) } });
    for (0.., @as([elems.len]Elem, elems)) |index, elem| {
        std.mem.writeInt(
            ElemInt,
            arr[len_size + elem_size * index ..][0..elem_size],
            switch (@typeInfo(Elem)) {
                .int => @as(Elem, elem),
                .@"enum" => @intFromEnum(@as(Elem, elem)),
                else => @bitCast(@as(Elem, elem)),
            },
            .big,
        );
    }
    return arr;
}

pub inline fn int(comptime Int: type, val: Int) [@divExact(@bitSizeOf(Int), 8)]u8 {
    var arr: [@divExact(@bitSizeOf(Int), 8)]u8 = undefined;
    std.mem.writeInt(Int, &arr, val, .big);
    return arr;
}

/// An abstraction to ensure that protocol-parsing code does not perform an
/// out-of-bounds read.
pub const Decoder = struct {
    buf: []u8,
    /// Points to the next byte in buffer that will be decoded.
    idx: usize = 0,
    /// Up to this point in `buf` we have already checked that `cap` is greater than it.
    our_end: usize = 0,
    /// Beyond this point in `buf` is extra tag-along bytes beyond the amount we
    /// requested with `readAtLeast`.
    their_end: usize = 0,
    /// Points to the end within buffer that has been filled. Beyond this point
    /// in buf is undefined bytes.
    cap: usize = 0,
    /// Debug helper to prevent illegal calls to read functions.
    disable_reads: bool = false,

    pub fn fromTheirSlice(buf: []u8) Decoder {
        return .{
            .buf = buf,
            .their_end = buf.len,
            .cap = buf.len,
            .disable_reads = true,
        };
    }

    /// Use this function to increase `their_end`.
    pub fn readAtLeast(d: *Decoder, stream: anytype, their_amt: usize) !void {
        assert(!d.disable_reads);
        const existing_amt = d.cap - d.idx;
        d.their_end = d.idx + their_amt;
        if (their_amt <= existing_amt) return;
        const request_amt = their_amt - existing_amt;
        const dest = d.buf[d.cap..];
        if (request_amt > dest.len) return error.TlsRecordOverflow;
        const actual_amt = try stream.readAtLeast(dest, request_amt);
        if (actual_amt < request_amt) return error.TlsConnectionTruncated;
        d.cap += actual_amt;
    }

    /// Same as `readAtLeast` but also increases `our_end` by exactly `our_amt`.
    /// Use when `our_amt` is calculated by us, not by them.
    pub fn readAtLeastOurAmt(d: *Decoder, stream: anytype, our_amt: usize) !void {
        assert(!d.disable_reads);
        try readAtLeast(d, stream, our_amt);
        d.our_end = d.idx + our_amt;
    }

    /// Use this function to increase `our_end`.
    /// This should always be called with an amount provided by us, not them.
    pub fn ensure(d: *Decoder, amt: usize) !void {
        d.our_end = @max(d.idx + amt, d.our_end);
        if (d.our_end > d.their_end) return error.TlsDecodeError;
    }

    /// Use this function to increase `idx`.
    pub fn decode(d: *Decoder, comptime T: type) T {
        switch (@typeInfo(T)) {
            .int => |info| switch (info.bits) {
                8 => {
                    skip(d, 1);
                    return d.buf[d.idx - 1];
                },
                16 => {
                    skip(d, 2);
                    const b0: u16 = d.buf[d.idx - 2];
                    const b1: u16 = d.buf[d.idx - 1];
                    return (b0 << 8) | b1;
                },
                24 => {
                    skip(d, 3);
                    const b0: u24 = d.buf[d.idx - 3];
                    const b1: u24 = d.buf[d.idx - 2];
                    const b2: u24 = d.buf[d.idx - 1];
                    return (b0 << 16) | (b1 << 8) | b2;
                },
                else => @compileError("unsupported int type: " ++ @typeName(T)),
            },
            .@"enum" => |info| {
                if (info.is_exhaustive) @compileError("exhaustive enum cannot be used");
                return @enumFromInt(d.decode(info.tag_type));
            },
            else => @compileError("unsupported type: " ++ @typeName(T)),
        }
    }

    /// Use this function to increase `idx`.
    pub fn array(d: *Decoder, comptime len: usize) *[len]u8 {
        skip(d, len);
        return d.buf[d.idx - len ..][0..len];
    }

    /// Use this function to increase `idx`.
    pub fn slice(d: *Decoder, len: usize) []u8 {
        skip(d, len);
        return d.buf[d.idx - len ..][0..len];
    }

    /// Use this function to increase `idx`.
    pub fn skip(d: *Decoder, amt: usize) void {
        d.idx += amt;
        assert(d.idx <= d.our_end); // insufficient ensured bytes
    }

    pub fn eof(d: Decoder) bool {
        assert(d.our_end <= d.their_end);
        assert(d.idx <= d.our_end);
        return d.idx == d.their_end;
    }

    /// Provide the length they claim, and receive a sub-decoder specific to that slice.
    /// The parent decoder is advanced to the end.
    pub fn sub(d: *Decoder, their_len: usize) !Decoder {
        const end = d.idx + their_len;
        if (end > d.their_end) return error.TlsDecodeError;
        const sub_buf = d.buf[d.idx..end];
        d.idx = end;
        d.our_end = end;
        return fromTheirSlice(sub_buf);
    }

    pub fn rest(d: Decoder) []u8 {
        return d.buf[d.idx..d.cap];
    }
};

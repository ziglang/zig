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
    client_hello = 1,
    server_hello = 2,
    new_session_ticket = 4,
    end_of_early_data = 5,
    encrypted_extensions = 8,
    certificate = 11,
    certificate_request = 13,
    certificate_verify = 15,
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
        return switch (alert) {
            .close_notify => {}, // not an error
            .unexpected_message => error.TlsAlertUnexpectedMessage,
            .bad_record_mac => error.TlsAlertBadRecordMac,
            .record_overflow => error.TlsAlertRecordOverflow,
            .handshake_failure => error.TlsAlertHandshakeFailure,
            .bad_certificate => error.TlsAlertBadCertificate,
            .unsupported_certificate => error.TlsAlertUnsupportedCertificate,
            .certificate_revoked => error.TlsAlertCertificateRevoked,
            .certificate_expired => error.TlsAlertCertificateExpired,
            .certificate_unknown => error.TlsAlertCertificateUnknown,
            .illegal_parameter => error.TlsAlertIllegalParameter,
            .unknown_ca => error.TlsAlertUnknownCa,
            .access_denied => error.TlsAlertAccessDenied,
            .decode_error => error.TlsAlertDecodeError,
            .decrypt_error => error.TlsAlertDecryptError,
            .protocol_version => error.TlsAlertProtocolVersion,
            .insufficient_security => error.TlsAlertInsufficientSecurity,
            .internal_error => error.TlsAlertInternalError,
            .inappropriate_fallback => error.TlsAlertInappropriateFallback,
            .user_canceled => {}, // not an error
            .missing_extension => error.TlsAlertMissingExtension,
            .unsupported_extension => error.TlsAlertUnsupportedExtension,
            .unrecognized_name => error.TlsAlertUnrecognizedName,
            .bad_certificate_status_response => error.TlsAlertBadCertificateStatusResponse,
            .unknown_psk_identity => error.TlsAlertUnknownPskIdentity,
            .certificate_required => error.TlsAlertCertificateRequired,
            .no_application_protocol => error.TlsAlertNoApplicationProtocol,
            _ => error.TlsAlertUnknown,
        };
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

pub const CipherSuite = enum(u16) {
    AES_128_GCM_SHA256 = 0x1301,
    AES_256_GCM_SHA384 = 0x1302,
    CHACHA20_POLY1305_SHA256 = 0x1303,
    AES_128_CCM_SHA256 = 0x1304,
    AES_128_CCM_8_SHA256 = 0x1305,
    AEGIS_256_SHA512 = 0x1306,
    AEGIS_128L_SHA256 = 0x1307,
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

pub fn HandshakeCipherT(comptime AeadType: type, comptime HashType: type) type {
    return struct {
        pub const AEAD = AeadType;
        pub const Hash = HashType;
        pub const Hmac = crypto.auth.hmac.Hmac(Hash);
        pub const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        handshake_secret: [Hkdf.prk_length]u8,
        master_secret: [Hkdf.prk_length]u8,
        client_handshake_key: [AEAD.key_length]u8,
        server_handshake_key: [AEAD.key_length]u8,
        client_finished_key: [Hmac.key_length]u8,
        server_finished_key: [Hmac.key_length]u8,
        client_handshake_iv: [AEAD.nonce_length]u8,
        server_handshake_iv: [AEAD.nonce_length]u8,
        transcript_hash: Hash,
    };
}

pub const HandshakeCipher = union(enum) {
    AES_128_GCM_SHA256: HandshakeCipherT(crypto.aead.aes_gcm.Aes128Gcm, crypto.hash.sha2.Sha256),
    AES_256_GCM_SHA384: HandshakeCipherT(crypto.aead.aes_gcm.Aes256Gcm, crypto.hash.sha2.Sha384),
    CHACHA20_POLY1305_SHA256: HandshakeCipherT(crypto.aead.chacha_poly.ChaCha20Poly1305, crypto.hash.sha2.Sha256),
    AEGIS_256_SHA512: HandshakeCipherT(crypto.aead.aegis.Aegis256, crypto.hash.sha2.Sha512),
    AEGIS_128L_SHA256: HandshakeCipherT(crypto.aead.aegis.Aegis128L, crypto.hash.sha2.Sha256),
};

pub fn ApplicationCipherT(comptime AeadType: type, comptime HashType: type) type {
    return struct {
        pub const AEAD = AeadType;
        pub const Hash = HashType;
        pub const Hmac = crypto.auth.hmac.Hmac(Hash);
        pub const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        client_secret: [Hash.digest_length]u8,
        server_secret: [Hash.digest_length]u8,
        client_key: [AEAD.key_length]u8,
        server_key: [AEAD.key_length]u8,
        client_iv: [AEAD.nonce_length]u8,
        server_iv: [AEAD.nonce_length]u8,
    };
}

/// Encryption parameters for application traffic.
pub const ApplicationCipher = union(enum) {
    AES_128_GCM_SHA256: ApplicationCipherT(crypto.aead.aes_gcm.Aes128Gcm, crypto.hash.sha2.Sha256),
    AES_256_GCM_SHA384: ApplicationCipherT(crypto.aead.aes_gcm.Aes256Gcm, crypto.hash.sha2.Sha384),
    CHACHA20_POLY1305_SHA256: ApplicationCipherT(crypto.aead.chacha_poly.ChaCha20Poly1305, crypto.hash.sha2.Sha256),
    AEGIS_256_SHA512: ApplicationCipherT(crypto.aead.aegis.Aegis256, crypto.hash.sha2.Sha512),
    AEGIS_128L_SHA256: ApplicationCipherT(crypto.aead.aegis.Aegis128L, crypto.hash.sha2.Sha256),
};

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

pub inline fn extension(comptime et: ExtensionType, bytes: anytype) [2 + 2 + bytes.len]u8 {
    return int2(@intFromEnum(et)) ++ array(1, bytes);
}

pub inline fn array(comptime elem_size: comptime_int, bytes: anytype) [2 + bytes.len]u8 {
    comptime assert(bytes.len % elem_size == 0);
    return int2(bytes.len) ++ bytes;
}

pub inline fn enum_array(comptime E: type, comptime tags: []const E) [2 + @sizeOf(E) * tags.len]u8 {
    assert(@sizeOf(E) == 2);
    var result: [tags.len * 2]u8 = undefined;
    for (tags, 0..) |elem, i| {
        result[i * 2] = @as(u8, @truncate(@intFromEnum(elem) >> 8));
        result[i * 2 + 1] = @as(u8, @truncate(@intFromEnum(elem)));
    }
    return array(2, result);
}

pub inline fn int2(x: u16) [2]u8 {
    return .{
        @as(u8, @truncate(x >> 8)),
        @as(u8, @truncate(x)),
    };
}

pub inline fn int3(x: u24) [3]u8 {
    return .{
        @as(u8, @truncate(x >> 16)),
        @as(u8, @truncate(x >> 8)),
        @as(u8, @truncate(x)),
    };
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
                const int = d.decode(info.tag_type);
                if (info.is_exhaustive) @compileError("exhaustive enum cannot be used");
                return @as(T, @enumFromInt(int));
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

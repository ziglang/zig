const std = @import("../std.zig");
const Tls = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;

application_cipher: ApplicationCipher,
read_seq: u64,
write_seq: u64,
/// The size is enough to contain exactly one TLSCiphertext record.
partially_read_buffer: [max_ciphertext_record_len]u8,
/// The number of partially read bytes inside `partiall_read_buffer`.
partially_read_len: u15,
eof: bool,

pub const ciphertext_record_header_len = 5;
pub const max_ciphertext_len = (1 << 14) + 256;
pub const max_ciphertext_record_len = max_ciphertext_len + ciphertext_record_header_len;
pub const hello_retry_request_sequence = [32]u8{
    0xCF, 0x21, 0xAD, 0x74, 0xE5, 0x9A, 0x61, 0x11, 0xBE, 0x1D, 0x8C, 0x02, 0x1E, 0x65, 0xB8, 0x91,
    0xC2, 0xA2, 0x11, 0x16, 0x7A, 0xBB, 0x8C, 0x5E, 0x07, 0x9E, 0x09, 0xE2, 0xC8, 0xA8, 0x33, 0x9C,
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
};

pub const AlertLevel = enum(u8) {
    warning = 1,
    fatal = 2,
    _,
};

pub const AlertDescription = enum(u8) {
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

    _,
};

// Plaintext:
// * type: ContentType
// * legacy_record_version: u16 = 0x0303,
// * length: u16,
//   - The length (in bytes) of the following TLSPlaintext.fragment.  The
//     length MUST NOT exceed 2^14 bytes.
// * fragment: opaque
//   - the data being transmitted

// Ciphertext
// * ContentType opaque_type = application_data; /* 23 */
// * ProtocolVersion legacy_record_version = 0x0303; /* TLS v1.2 */
// * uint16 length;
// * opaque encrypted_record[TLSCiphertext.length];

// Handshake:
// * type: HandshakeType
// * length: u24
// * data: opaque

// ServerHello:
// * ProtocolVersion legacy_version = 0x0303;
// * Random random;
// * opaque legacy_session_id_echo<0..32>;
// * CipherSuite cipher_suite;
// * uint8 legacy_compression_method = 0;
// * Extension extensions<6..2^16-1>;

// Extension:
// * ExtensionType extension_type;
// * opaque extension_data<0..2^16-1>;

pub const CipherSuite = enum(u16) {
    TLS_AES_128_GCM_SHA256 = 0x1301,
    TLS_AES_256_GCM_SHA384 = 0x1302,
    TLS_CHACHA20_POLY1305_SHA256 = 0x1303,
    TLS_AES_128_CCM_SHA256 = 0x1304,
    TLS_AES_128_CCM_8_SHA256 = 0x1305,
};

pub const CipherParams = union(CipherSuite) {
    TLS_AES_128_GCM_SHA256: struct {
        const AEAD = crypto.aead.aes_gcm.Aes128Gcm;
        const Hash = crypto.hash.sha2.Sha256;
        const Hmac = crypto.auth.hmac.Hmac(Hash);
        const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        handshake_secret: [Hkdf.key_len]u8,
        master_secret: [Hkdf.key_len]u8,
        client_handshake_key: [AEAD.key_length]u8,
        server_handshake_key: [AEAD.key_length]u8,
        client_finished_key: [Hmac.key_length]u8,
        server_finished_key: [Hmac.key_length]u8,
        client_handshake_iv: [AEAD.nonce_length]u8,
        server_handshake_iv: [AEAD.nonce_length]u8,
        transcript_hash: Hash,
    },
    TLS_AES_256_GCM_SHA384: struct {
        const AEAD = crypto.aead.aes_gcm.Aes256Gcm;
        const Hash = crypto.hash.sha2.Sha384;
        const Hmac = crypto.auth.hmac.Hmac(Hash);
        const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        handshake_secret: [Hkdf.key_len]u8,
        master_secret: [Hkdf.key_len]u8,
        client_handshake_key: [AEAD.key_length]u8,
        server_handshake_key: [AEAD.key_length]u8,
        client_finished_key: [Hmac.key_length]u8,
        server_finished_key: [Hmac.key_length]u8,
        client_handshake_iv: [AEAD.nonce_length]u8,
        server_handshake_iv: [AEAD.nonce_length]u8,
        transcript_hash: Hash,
    },
    TLS_CHACHA20_POLY1305_SHA256: void,
    TLS_AES_128_CCM_SHA256: void,
    TLS_AES_128_CCM_8_SHA256: void,
};

/// Encryption parameters for application traffic.
pub const ApplicationCipher = union(CipherSuite) {
    TLS_AES_128_GCM_SHA256: struct {
        const AEAD = crypto.aead.aes_gcm.Aes128Gcm;
        const Hash = crypto.hash.sha2.Sha256;
        const Hmac = crypto.auth.hmac.Hmac(Hash);
        const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        client_key: [AEAD.key_length]u8,
        server_key: [AEAD.key_length]u8,
        client_iv: [AEAD.nonce_length]u8,
        server_iv: [AEAD.nonce_length]u8,
    },
    TLS_AES_256_GCM_SHA384: struct {
        const AEAD = crypto.aead.aes_gcm.Aes256Gcm;
        const Hash = crypto.hash.sha2.Sha384;
        const Hmac = crypto.auth.hmac.Hmac(Hash);
        const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        client_key: [AEAD.key_length]u8,
        server_key: [AEAD.key_length]u8,
        client_iv: [AEAD.nonce_length]u8,
        server_iv: [AEAD.nonce_length]u8,
    },
    TLS_CHACHA20_POLY1305_SHA256: void,
    TLS_AES_128_CCM_SHA256: void,
    TLS_AES_128_CCM_8_SHA256: void,
};

const cipher_suites = blk: {
    const fields = @typeInfo(CipherSuite).Enum.fields;
    var result: [(fields.len + 1) * 2]u8 = undefined;
    mem.writeIntBig(u16, result[0..2], result.len - 2);
    for (fields) |field, i| {
        const int = @enumToInt(@field(CipherSuite, field.name));
        result[(i + 1) * 2] = @truncate(u8, int >> 8);
        result[(i + 1) * 2 + 1] = @truncate(u8, int);
    }
    break :blk result;
};

/// `host` is only borrowed during this function call.
pub fn init(stream: net.Stream, host: []const u8) !Tls {
    var x25519_priv_key: [32]u8 = undefined;
    crypto.random.bytes(&x25519_priv_key);
    const x25519_pub_key = crypto.dh.X25519.recoverPublicKey(x25519_priv_key) catch |err| {
        switch (err) {
            // Only possible to happen if the private key is all zeroes.
            error.IdentityElement => return error.InsufficientEntropy,
        }
    };

    // random (u32)
    var rand_buf: [32]u8 = undefined;
    crypto.random.bytes(&rand_buf);

    const extensions_header = [_]u8{
        // Extensions byte length
        undefined, undefined,

        // Extension: supported_versions (only TLS 1.3)
        0, 43, // ExtensionType.supported_versions
        0x00, 0x05, // byte length of this extension payload
        0x04, // byte length of supported versions
        0x03, 0x04, // TLS 1.3
        0x03, 0x03, // TLS 1.2

        // Extension: signature_algorithms
        0, 13, // ExtensionType.signature_algorithms
        0x00, 0x22, // byte length of this extension payload
        0x00, 0x20, // byte length of signature algorithms list
        0x04, 0x01, // rsa_pkcs1_sha256
        0x05, 0x01, // rsa_pkcs1_sha384
        0x06, 0x01, // rsa_pkcs1_sha512
        0x04, 0x03, // ecdsa_secp256r1_sha256
        0x05, 0x03, // ecdsa_secp384r1_sha384
        0x06, 0x03, // ecdsa_secp521r1_sha512
        0x08, 0x04, // rsa_pss_rsae_sha256
        0x08, 0x05, // rsa_pss_rsae_sha384
        0x08, 0x06, // rsa_pss_rsae_sha512
        0x08, 0x07, // ed25519
        0x08, 0x08, // ed448
        0x08, 0x09, // rsa_pss_pss_sha256
        0x08, 0x0a, // rsa_pss_pss_sha384
        0x08, 0x0b, // rsa_pss_pss_sha512
        0x02, 0x01, // rsa_pkcs1_sha1
        0x02, 0x03, // ecdsa_sha1

        // Extension: supported_groups
        0, 10, // ExtensionType.supported_groups
        0x00, 0x0c, // byte length of this extension payload
        0x00, 0x0a, // byte length of supported groups list
        0x00, 0x17, // secp256r1
        0x00, 0x18, // secp384r1
        0x00, 0x19, // secp521r1
        0x00, 0x1D, // x25519
        0x00, 0x1E, // x448

        // Extension: key_share
        0, 51, // ExtensionType.key_share
        0, 38, // byte length of this extension payload
        0, 36, // byte length of client_shares
        0x00, 0x1D, // NamedGroup.x25519
        0, 32, // byte length of key_exchange
    } ++ x25519_pub_key ++ [_]u8{

        // Extension: server_name
        0, 0, // ExtensionType.server_name
        undefined, undefined, // byte length of this extension payload
        undefined, undefined, // server_name_list byte count
        0x00, // name_type
        undefined, undefined, // host name len
    };

    var hello_header = [_]u8{
        // Plaintext header
        @enumToInt(ContentType.handshake),
        0x03, 0x01, // legacy_record_version
        undefined,                              undefined, // Plaintext fragment length (u16)

        // Handshake header
        @enumToInt(HandshakeType.client_hello),
        undefined, undefined, undefined, // handshake length (u24)

        // ClientHello
        0x03, 0x03, // legacy_version
    } ++ rand_buf ++ [1]u8{0} ++ cipher_suites ++ [_]u8{
        0x01, 0x00, // legacy_compression_methods
    } ++ extensions_header;

    mem.writeIntBig(u16, hello_header[3..][0..2], @intCast(u16, hello_header.len - 5 + host.len));
    mem.writeIntBig(u24, hello_header[6..][0..3], @intCast(u24, hello_header.len - 9 + host.len));
    mem.writeIntBig(
        u16,
        hello_header[hello_header.len - extensions_header.len ..][0..2],
        @intCast(u16, extensions_header.len - 2 + host.len),
    );
    mem.writeIntBig(u16, hello_header[hello_header.len - 7 ..][0..2], @intCast(u16, 5 + host.len));
    mem.writeIntBig(u16, hello_header[hello_header.len - 5 ..][0..2], @intCast(u16, 3 + host.len));
    mem.writeIntBig(u16, hello_header[hello_header.len - 2 ..][0..2], @intCast(u16, 0 + host.len));

    {
        var iovecs = [_]std.os.iovec_const{
            .{
                .iov_base = &hello_header,
                .iov_len = hello_header.len,
            },
            .{
                .iov_base = host.ptr,
                .iov_len = host.len,
            },
        };
        try stream.writevAll(&iovecs);
    }

    const client_hello_bytes1 = hello_header[5..];

    var cipher_params: CipherParams = undefined;

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
                const level = @intToEnum(AlertLevel, frag[0]);
                const desc = @intToEnum(AlertDescription, frag[1]);
                std.debug.print("alert: {s} {s}\n", .{ @tagName(level), @tagName(desc) });
                return error.TlsAlert;
            },
            .handshake => {
                if (frag[0] != @enumToInt(HandshakeType.server_hello)) {
                    return error.TlsUnexpectedMessage;
                }
                const length = mem.readIntBig(u24, frag[1..4]);
                if (4 + length != frag.len) return error.TlsBadLength;
                const hello = frag[4..];
                const legacy_version = mem.readIntBig(u16, hello[0..2]);
                const random = hello[2..34].*;
                if (mem.eql(u8, &random, &hello_retry_request_sequence)) {
                    @panic("TODO handle HelloRetryRequest");
                }
                const legacy_session_id_echo_len = hello[34];
                if (legacy_session_id_echo_len != 0) return error.TlsIllegalParameter;
                const cipher_suite_int = mem.readIntBig(u16, hello[35..37]);
                const cipher_suite_tag = std.meta.intToEnum(CipherSuite, cipher_suite_int) catch
                    return error.TlsIllegalParameter;
                std.debug.print("server wants cipher suite {s}\n", .{@tagName(cipher_suite_tag)});
                const legacy_compression_method = hello[37];
                _ = legacy_compression_method;
                const extensions_size = mem.readIntBig(u16, hello[38..40]);
                if (40 + extensions_size != hello.len) return error.TlsBadLength;
                var i: usize = 40;
                var supported_version: u16 = 0;
                var opt_x25519_server_pub_key: ?*[32]u8 = null;
                while (i < hello.len) {
                    const et = mem.readIntBig(u16, hello[i..][0..2]);
                    i += 2;
                    const ext_size = mem.readIntBig(u16, hello[i..][0..2]);
                    i += 2;
                    const next_i = i + ext_size;
                    if (next_i > hello.len) return error.TlsBadLength;
                    switch (et) {
                        @enumToInt(ExtensionType.supported_versions) => {
                            if (supported_version != 0) return error.TlsIllegalParameter;
                            supported_version = mem.readIntBig(u16, hello[i..][0..2]);
                        },
                        @enumToInt(ExtensionType.key_share) => {
                            if (opt_x25519_server_pub_key != null) return error.TlsIllegalParameter;
                            const named_group = mem.readIntBig(u16, hello[i..][0..2]);
                            i += 2;
                            switch (named_group) {
                                @enumToInt(NamedGroup.x25519) => {
                                    const key_size = mem.readIntBig(u16, hello[i..][0..2]);
                                    i += 2;
                                    if (key_size != 32) return error.TlsBadLength;
                                    opt_x25519_server_pub_key = hello[i..][0..32];
                                },
                                else => {
                                    std.debug.print("named group: {x}\n", .{named_group});
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
                const x25519_server_pub_key = opt_x25519_server_pub_key orelse
                    return error.TlsIllegalParameter;
                const tls_version = if (supported_version == 0) legacy_version else supported_version;
                switch (tls_version) {
                    @enumToInt(ProtocolVersion.tls_1_2) => {
                        std.debug.print("server wants TLS v1.2\n", .{});
                    },
                    @enumToInt(ProtocolVersion.tls_1_3) => {
                        std.debug.print("server wants TLS v1.3\n", .{});
                    },
                    else => return error.TlsIllegalParameter,
                }

                const shared_key = crypto.dh.X25519.scalarmult(
                    x25519_priv_key,
                    x25519_server_pub_key.*,
                ) catch return error.TlsDecryptFailure;

                switch (cipher_suite_tag) {
                    inline .TLS_AES_128_GCM_SHA256, .TLS_AES_256_GCM_SHA384 => |tag| {
                        const P = std.meta.TagPayload(CipherParams, tag);
                        cipher_params = @unionInit(CipherParams, @tagName(tag), .{
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
                        const p = &@field(cipher_params, @tagName(tag));
                        p.transcript_hash.update(client_hello_bytes1); // Client Hello part 1
                        p.transcript_hash.update(host); // Client Hello part 2
                        p.transcript_hash.update(frag); // Server Hello
                        const hello_hash = p.transcript_hash.peek();
                        const zeroes = [1]u8{0} ** P.Hash.digest_length;
                        const early_secret = P.Hkdf.extract(&[1]u8{0}, &zeroes);
                        const empty_hash = emptyHash(P.Hash);
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
                    .TLS_CHACHA20_POLY1305_SHA256 => {
                        @panic("TODO");
                    },
                    .TLS_AES_128_CCM_SHA256 => {
                        @panic("TODO");
                    },
                    .TLS_AES_128_CCM_8_SHA256 => {
                        @panic("TODO");
                    },
                }
            },
            else => return error.TlsUnexpectedMessage,
        }
        break :i end;
    };

    var read_seq: u64 = 0;

    while (true) {
        const end_hdr = i + 5;
        if (end_hdr > handshake_buf.len) return error.TlsRecordOverflow;
        if (end_hdr > len) {
            std.debug.print("read len={d} atleast={d}\n", .{ len, end_hdr - len });
            len += try stream.readAtLeast(handshake_buf[len..], end_hdr - len);
            std.debug.print("new len: {d} bytes\n", .{len});
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
        std.debug.print("ct={any} record_size={d} end={d}\n", .{ ct, record_size, end });
        if (end > handshake_buf.len) return error.TlsRecordOverflow;
        if (end > len) {
            std.debug.print("read len={d} atleast={d}\n", .{ len, end - len });
            len += try stream.readAtLeast(handshake_buf[len..], end - len);
            std.debug.print("new len: {d} bytes\n", .{len});
            if (end > len) return error.EndOfStream;
        }
        switch (ct) {
            .change_cipher_spec => {
                if (record_size != 1) return error.TlsUnexpectedMessage;
                if (handshake_buf[i] != 0x01) return error.TlsUnexpectedMessage;
            },
            .application_data => {
                var cleartext_buf: [8000]u8 = undefined;
                const cleartext = switch (cipher_params) {
                    inline .TLS_AES_128_GCM_SHA256, .TLS_AES_256_GCM_SHA384 => |*p| c: {
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
                        const nonce: [P.AEAD.nonce_length]u8 = @as(V, p.server_handshake_iv) ^ operand;
                        const ad = handshake_buf[end_hdr - 5 ..][0..5];
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag, ad, nonce, p.server_handshake_key) catch
                            return error.TlsBadRecordMac;
                        p.transcript_hash.update(cleartext[0 .. cleartext.len - 1]);
                        break :c cleartext;
                    },
                    .TLS_CHACHA20_POLY1305_SHA256 => {
                        @panic("TODO");
                    },
                    .TLS_AES_128_CCM_SHA256 => {
                        @panic("TODO");
                    },
                    .TLS_AES_128_CCM_8_SHA256 => {
                        @panic("TODO");
                    },
                };

                const inner_ct = @intToEnum(ContentType, cleartext[cleartext.len - 1]);
                switch (inner_ct) {
                    .handshake => {
                        var ct_i: usize = 0;
                        while (true) {
                            const handshake_type = cleartext[ct_i];
                            ct_i += 1;
                            const handshake_len = mem.readIntBig(u24, cleartext[ct_i..][0..3]);
                            ct_i += 3;
                            const next_handshake_i = ct_i + handshake_len;
                            if (next_handshake_i > cleartext.len - 1)
                                return error.TlsBadLength;
                            switch (handshake_type) {
                                @enumToInt(HandshakeType.encrypted_extensions) => {
                                    const ext_size = mem.readIntBig(u16, cleartext[ct_i..][0..2]);
                                    ct_i += 2;
                                    std.debug.print("{d} bytes of encrypted extensions\n", .{
                                        ext_size,
                                    });
                                },
                                @enumToInt(HandshakeType.certificate) => {
                                    std.debug.print("cool certificate bro\n", .{});
                                },
                                @enumToInt(HandshakeType.certificate_verify) => {
                                    std.debug.print("the certificate came with a fancy signature\n", .{});
                                },
                                @enumToInt(HandshakeType.finished) => {
                                    // This message is to trick buggy proxies into behaving correctly.
                                    const client_change_cipher_spec_msg = [_]u8{
                                        @enumToInt(ContentType.change_cipher_spec),
                                        0x03, 0x03, // legacy protocol version
                                        0x00, 0x01, // length
                                        0x01,
                                    };
                                    const app_cipher = switch (cipher_params) {
                                        inline .TLS_AES_128_GCM_SHA256, .TLS_AES_256_GCM_SHA384 => |*p, tag| c: {
                                            const P = @TypeOf(p.*);
                                            // TODO verify the server's data
                                            const handshake_hash = p.transcript_hash.finalResult();
                                            const verify_data = hmac(P.Hmac, &handshake_hash, p.client_finished_key);
                                            const out_cleartext = [_]u8{
                                                @enumToInt(HandshakeType.finished),
                                                0, 0, verify_data.len, // length
                                            } ++ verify_data ++ [1]u8{@enumToInt(ContentType.handshake)};

                                            const wrapped_len = out_cleartext.len + P.AEAD.tag_length;

                                            var finished_msg = [_]u8{
                                                @enumToInt(ContentType.application_data),
                                                0x03, 0x03, // legacy protocol version
                                                0, wrapped_len, // byte length of encrypted record
                                            } ++ ([1]u8{undefined} ** wrapped_len);

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
                                                .client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length),
                                                .server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length),
                                                .client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length),
                                                .server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length),
                                            });
                                        },
                                        .TLS_CHACHA20_POLY1305_SHA256 => {
                                            @panic("TODO");
                                        },
                                        .TLS_AES_128_CCM_SHA256 => {
                                            @panic("TODO");
                                        },
                                        .TLS_AES_128_CCM_8_SHA256 => {
                                            @panic("TODO");
                                        },
                                    };
                                    std.debug.print("remaining bytes: {d}\n", .{len - end});
                                    return .{
                                        .application_cipher = app_cipher,
                                        .read_seq = 0,
                                        .write_seq = 0,
                                        .partially_read_buffer = undefined,
                                        .partially_read_len = 0,
                                        .eof = false,
                                    };
                                },
                                else => {
                                    std.debug.print("handshake type: {d}\n", .{cleartext[0]});
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

pub fn write(tls: *Tls, stream: net.Stream, bytes: []const u8) !usize {
    var ciphertext_buf: [max_ciphertext_record_len * 4]u8 = undefined;
    // Due to the trailing inner content type byte in the ciphertext, we need
    // an additional buffer for storing the cleartext into before encrypting.
    var cleartext_buf: [max_ciphertext_len]u8 = undefined;
    var iovecs_buf: [5]std.os.iovec_const = undefined;
    var ciphertext_end: usize = 0;
    var iovec_end: usize = 0;
    var bytes_i: usize = 0;
    // How many bytes are taken up by overhead per record.
    const overhead_len: usize = switch (tls.application_cipher) {
        inline .TLS_AES_128_GCM_SHA256, .TLS_AES_256_GCM_SHA384 => |*p| l: {
            const P = @TypeOf(p.*);
            const V = @Vector(P.AEAD.nonce_length, u8);
            const overhead_len = ciphertext_record_header_len + P.AEAD.tag_length + 1;
            while (true) {
                const encrypted_content_len = @intCast(u16, @min(
                    @min(bytes.len - bytes_i, max_ciphertext_len - 1),
                    ciphertext_buf.len -
                        ciphertext_record_header_len - P.AEAD.tag_length - ciphertext_end - 1,
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
                    int2(@enumToInt(ProtocolVersion.tls_1_2)) ++
                    int2(ciphertext_len + P.AEAD.tag_length);
                ciphertext_end += ad.len;
                const ciphertext = ciphertext_buf[ciphertext_end..][0..ciphertext_len];
                ciphertext_end += ciphertext_len;
                const auth_tag = ciphertext_buf[ciphertext_end..][0..P.AEAD.tag_length];
                ciphertext_end += auth_tag.len;
                const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                const operand: V = pad ++ @bitCast([8]u8, big(tls.write_seq));
                tls.write_seq += 1;
                const nonce: [P.AEAD.nonce_length]u8 = @as(V, p.client_iv) ^ operand;
                P.AEAD.encrypt(ciphertext, auth_tag, cleartext, ad, nonce, p.client_key);
                //std.debug.print("seq: {d} nonce: {} client_key: {} client_iv: {} ad: {} auth_tag: {}\nserver_key: {} server_iv: {}\n", .{
                //    tls.write_seq - 1,
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
        .TLS_CHACHA20_POLY1305_SHA256 => {
            @panic("TODO");
        },
        .TLS_AES_128_CCM_SHA256 => {
            @panic("TODO");
        },
        .TLS_AES_128_CCM_8_SHA256 => {
            @panic("TODO");
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

pub fn writeAll(tls: *Tls, stream: net.Stream, bytes: []const u8) !void {
    var index: usize = 0;
    while (index < bytes.len) {
        index += try tls.write(stream, bytes[index..]);
    }
}

/// Returns number of bytes that have been read, which are now populated inside
/// `buffer`. A return value of zero bytes does not necessarily mean end of
/// stream.
pub fn read(tls: *Tls, stream: net.Stream, buffer: []u8) !usize {
    const prev_len = tls.partially_read_len;
    var in_buf: [max_ciphertext_len * 4]u8 = undefined;
    mem.copy(u8, &in_buf, tls.partially_read_buffer[0..prev_len]);

    // Capacity of output buffer, in records, rounded up.
    const buf_cap = (buffer.len +| (max_ciphertext_len - 1)) / max_ciphertext_len;
    const wanted_read_len = buf_cap * (max_ciphertext_len + ciphertext_record_header_len);
    const actual_read_len = try stream.read(in_buf[prev_len..@min(wanted_read_len, in_buf.len)]);
    const frag = in_buf[0 .. prev_len + actual_read_len];
    if (frag.len == 0) {
        tls.eof = true;
        return 0;
    }
    std.debug.print("actual_read_len={d} frag.len={d}\n", .{ actual_read_len, frag.len });
    var in: usize = 0;
    var out: usize = 0;

    while (true) {
        if (in + ciphertext_record_header_len > frag.len) {
            std.debug.print("in={d} frag.len={d}\n", .{ in, frag.len });
            return finishRead(tls, frag, in, out);
        }
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
            std.debug.print("end={d} frag.len={d}\n", .{ end, frag.len });
            return finishRead(tls, frag, in, out);
        }
        switch (ct) {
            .alert => {
                @panic("TODO handle an alert here");
            },
            .application_data => {
                const cleartext_len = switch (tls.application_cipher) {
                    inline .TLS_AES_128_GCM_SHA256, .TLS_AES_256_GCM_SHA384 => |*p| c: {
                        const P = @TypeOf(p.*);
                        const V = @Vector(P.AEAD.nonce_length, u8);
                        const ad = frag[in - 5 ..][0..5];
                        const ciphertext_len = record_size - P.AEAD.tag_length;
                        const ciphertext = frag[in..][0..ciphertext_len];
                        in += ciphertext_len;
                        const auth_tag = frag[in..][0..P.AEAD.tag_length].*;
                        const cleartext = buffer[out..][0..ciphertext_len];
                        const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                        const operand: V = pad ++ @bitCast([8]u8, big(tls.read_seq));
                        tls.read_seq += 1;
                        const nonce: [P.AEAD.nonce_length]u8 = @as(V, p.server_iv) ^ operand;
                        //std.debug.print("seq: {d} nonce: {} server_key: {} server_iv: {}\n", .{
                        //    tls.read_seq - 1,
                        //    std.fmt.fmtSliceHexLower(&nonce),
                        //    std.fmt.fmtSliceHexLower(&p.server_key),
                        //    std.fmt.fmtSliceHexLower(&p.server_iv),
                        //});
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag, ad, nonce, p.server_key) catch
                            return error.TlsBadRecordMac;
                        break :c cleartext.len;
                    },
                    .TLS_CHACHA20_POLY1305_SHA256 => {
                        @panic("TODO");
                    },
                    .TLS_AES_128_CCM_SHA256 => {
                        @panic("TODO");
                    },
                    .TLS_AES_128_CCM_8_SHA256 => {
                        @panic("TODO");
                    },
                };

                const inner_ct = @intToEnum(ContentType, buffer[out + cleartext_len - 1]);
                switch (inner_ct) {
                    .alert => {
                        const level = @intToEnum(AlertLevel, buffer[out]);
                        const desc = @intToEnum(AlertDescription, buffer[out + 1]);
                        if (desc == .close_notify) {
                            tls.eof = true;
                            return out;
                        }
                        std.debug.print("alert: {s} {s}\n", .{ @tagName(level), @tagName(desc) });
                        return error.TlsAlert;
                    },
                    .handshake => {
                        std.debug.print("the server wants to keep shaking hands\n", .{});
                    },
                    .application_data => {
                        out += cleartext_len - 1;
                    },
                    else => {
                        std.debug.print("inner content type: {d}\n", .{inner_ct});
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

fn finishRead(tls: *Tls, frag: []const u8, in: usize, out: usize) usize {
    const saved_buf = frag[in..];
    mem.copy(u8, &tls.partially_read_buffer, saved_buf);
    tls.partially_read_len = @intCast(u15, saved_buf.len);
    return out;
}

fn hkdfExpandLabel(
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
    mem.writeIntBig(u16, buf[0..2], len);
    buf[2] = @intCast(u8, tls13.len + label.len);
    buf[3..][0..tls13.len].* = tls13.*;
    var i: usize = 3 + tls13.len;
    mem.copy(u8, buf[i..], label);
    i += label.len;
    buf[i] = @intCast(u8, context.len);
    i += 1;
    mem.copy(u8, buf[i..], context);
    i += context.len;

    var result: [len]u8 = undefined;
    Hkdf.expand(&result, buf[0..i], key);
    return result;
}

fn emptyHash(comptime Hash: type) [Hash.digest_length]u8 {
    var result: [Hash.digest_length]u8 = undefined;
    Hash.hash(&.{}, &result, .{});
    return result;
}

fn hmac(comptime Hmac: type, message: []const u8, key: [Hmac.key_length]u8) [Hmac.mac_length]u8 {
    var result: [Hmac.mac_length]u8 = undefined;
    Hmac.create(&result, message, &key);
    return result;
}

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

inline fn big(x: anytype) @TypeOf(x) {
    return switch (native_endian) {
        .Big => x,
        .Little => @byteSwap(x),
    };
}

inline fn int2(x: u16) [2]u8 {
    return .{
        @truncate(u8, x >> 8),
        @truncate(u8, x),
    };
}

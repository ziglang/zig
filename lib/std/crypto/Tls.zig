const std = @import("../std.zig");
const Tls = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;

state: State = .start,
x25519_priv_key: [32]u8 = undefined,
x25519_pub_key: [32]u8 = undefined,
x25519_server_pub_key: [32]u8 = undefined,

const ProtocolVersion = enum(u16) {
    tls_1_2 = 0x0303,
    tls_1_3 = 0x0304,
    _,
};

const State = enum {
    /// In this state, all fields are undefined except state.
    start,
    sent_hello,
};

const ContentType = enum(u8) {
    invalid = 0,
    change_cipher_spec = 20,
    alert = 21,
    handshake = 22,
    application_data = 23,
    _,
};

const HandshakeType = enum(u8) {
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

const ExtensionType = enum(u16) {
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

const AlertLevel = enum(u8) {
    warning = 1,
    fatal = 2,
    _,
};

const AlertDescription = enum(u8) {
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

const SignatureScheme = enum(u16) {
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

const NamedGroup = enum(u16) {
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

const CipherSuite = enum(u16) {
    TLS_AES_128_GCM_SHA256 = 0x1301,
    TLS_AES_256_GCM_SHA384 = 0x1302,
    TLS_CHACHA20_POLY1305_SHA256 = 0x1303,
    TLS_AES_128_CCM_SHA256 = 0x1304,
    TLS_AES_128_CCM_8_SHA256 = 0x1305,
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

pub fn init(tls: *Tls, stream: net.Stream, host: []const u8) !void {
    assert(tls.state == .start);
    crypto.random.bytes(&tls.x25519_priv_key);
    tls.x25519_pub_key = try crypto.dh.X25519.recoverPublicKey(tls.x25519_priv_key);

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
    } ++ tls.x25519_pub_key ++ [_]u8{

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

    {
        var handshake_buf: [4000]u8 = undefined;
        const plaintext = handshake_buf[0..5];
        const amt = try stream.readAtLeast(&handshake_buf, plaintext.len);
        if (amt < plaintext.len) return error.EndOfStream;
        const ct = @intToEnum(ContentType, plaintext[0]);
        const frag_len = mem.readIntBig(u16, plaintext[3..][0..2]);
        const end = plaintext.len + frag_len;
        if (end > handshake_buf.len) return error.TlsServerHelloTooBig;
        if (amt < end) {
            const amt2 = try stream.readAll(handshake_buf[amt..end]);
            if (amt2 < plaintext.len) return error.EndOfStream;
        }
        const frag = handshake_buf[plaintext.len..end];

        if (ct == .alert) {
            const level = @intToEnum(AlertLevel, frag[0]);
            const desc = @intToEnum(AlertDescription, frag[1]);
            std.debug.print("alert: {s} {s}\n", .{ @tagName(level), @tagName(desc) });
            std.process.exit(1);
        } else if (ct == .handshake) {
            if (frag[0] != @enumToInt(HandshakeType.server_hello)) {
                return error.TlsUnexpectedMessage;
            }
            const length = mem.readIntBig(u24, frag[1..4]);
            if (4 + length != frag.len) return error.TlsBadLength;
            const hello = frag[4..];
            const legacy_version = mem.readIntBig(u16, hello[0..2]);
            const random = hello[2..34].*;
            _ = random;
            const legacy_session_id_echo_len = hello[34];
            if (legacy_session_id_echo_len != 0) return error.TlsIllegalParameter;
            const cipher_suite_int = mem.readIntBig(u16, hello[35..37]);
            const cipher_suite = std.meta.intToEnum(CipherSuite, cipher_suite_int) catch
                return error.TlsIllegalParameter;
            std.debug.print("server wants cipher suite {s}\n", .{@tagName(cipher_suite)});
            const legacy_compression_method = hello[37];
            _ = legacy_compression_method;
            const extensions_size = mem.readIntBig(u16, hello[38..40]);
            if (40 + extensions_size != hello.len) return error.TlsBadLength;
            var i: usize = 40;
            var supported_version: u16 = 0;
            var have_server_pub_key = false;
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
                        if (have_server_pub_key) return error.TlsIllegalParameter;
                        const named_group = mem.readIntBig(u16, hello[i..][0..2]);
                        i += 2;
                        switch (named_group) {
                            @enumToInt(NamedGroup.x25519) => {
                                const key_size = mem.readIntBig(u16, hello[i..][0..2]);
                                i += 2;
                                if (key_size != 32) return error.TlsBadLength;
                                const encrypted_key = hello[i..][0..32].*;
                                const server_pub_key = try crypto.dh.X25519.scalarmult(
                                    tls.x25519_priv_key,
                                    encrypted_key,
                                );
                                tls.x25519_server_pub_key = server_pub_key;
                                have_server_pub_key = true;
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
            if (!have_server_pub_key) return error.TlsIllegalParameter;
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
        } else {
            std.debug.print("content_type: {s}\n", .{@tagName(ct)});
            std.debug.print("got {d} bytes: {s}\n", .{ amt, std.fmt.fmtSliceHexLower(frag) });
        }
    }

    tls.state = .sent_hello;
}

pub fn writeAll(tls: *Tls, stream: net.Stream, buffer: []const u8) !void {
    _ = tls;
    _ = stream;
    _ = buffer;
    @panic("hold on a minute, we didn't finish implementing the handshake yet");
}

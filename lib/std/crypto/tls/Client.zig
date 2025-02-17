const std = @import("../../std.zig");
const tls = std.crypto.tls;
const Client = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const Certificate = std.crypto.Certificate;

const max_ciphertext_len = tls.max_ciphertext_len;
const hmacExpandLabel = tls.hmacExpandLabel;
const hkdfExpandLabel = tls.hkdfExpandLabel;
const int = tls.int;
const array = tls.array;

tls_version: tls.ProtocolVersion,
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
allow_truncation_attacks: bool,
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
/// If non-null, ssl secrets are logged to a file.  Creating such a log file allows other
/// programs with access to that file to decrypt all traffic over this connection.
ssl_key_log: ?struct {
    client_key_seq: u64,
    server_key_seq: u64,
    client_random: [32]u8,
    file: std.fs.File,

    fn clientCounter(key_log: *@This()) u64 {
        defer key_log.client_key_seq += 1;
        return key_log.client_key_seq;
    }

    fn serverCounter(key_log: *@This()) u64 {
        defer key_log.server_key_seq += 1;
        return key_log.server_key_seq;
    }
},

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

    /// The `iovecs` parameter is mutable in case this function needs to mutate
    /// the fields in order to handle partial writes from the underlying layer.
    pub fn writevAll(this: @This(), iovecs: []std.posix.iovec_const) WriteError!void {
        // This can be implemented in terms of writev, or specialized if desired.
        _ = .{ this, iovecs };
        @panic("unimplemented");
    }
};

pub const Options = struct {
    /// How to perform host verification of server certificates.
    host: union(enum) {
        /// No host verification is performed, which prevents a trusted connection from
        /// being established.
        no_verification,
        /// Verify that the server certificate was issues for a given host.
        explicit: []const u8,
    },
    /// How to verify the authenticity of server certificates.
    ca: union(enum) {
        /// No ca verification is performed, which prevents a trusted connection from
        /// being established.
        no_verification,
        /// Verify that the server certificate is a valid self-signed certificate.
        /// This provides no authorization guarantees, as anyone can create a
        /// self-signed certificate.
        self_signed,
        /// Verify that the server certificate is authorized by a given ca bundle.
        bundle: Certificate.Bundle,
    },
    /// If non-null, ssl secrets are logged to this stream.  Creating such a log file allows
    /// other programs with access to that file to decrypt all traffic over this connection.
    ssl_key_log_file: ?*std.io.BufferedWriter = null,
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

/// Initiates a TLS handshake and establishes a TLSv1.2 or TLSv1.3 session with `stream`, which
/// must conform to `StreamInterface`.
///
/// `host` is only borrowed during this function call.
pub fn init(stream: anytype, options: Options) InitError(@TypeOf(stream))!Client {
    const host = switch (options.host) {
        .no_verification => "",
        .explicit => |host| host,
    };
    const host_len: u16 = @intCast(host.len);

    var random_buffer: [176]u8 = undefined;
    crypto.random.bytes(&random_buffer);
    const client_hello_rand = random_buffer[0..32].*;
    var key_seq: u64 = 0;
    var server_hello_rand: [32]u8 = undefined;
    const legacy_session_id = random_buffer[32..64].*;

    var key_share = KeyShare.init(random_buffer[64..176].*) catch |err| switch (err) {
        // Only possible to happen if the seed is all zeroes.
        error.IdentityElement => return error.InsufficientEntropy,
    };

    const extensions_payload = tls.extension(.supported_versions, array(u8, tls.ProtocolVersion, .{
        .tls_1_3,
        .tls_1_2,
    })) ++ tls.extension(.signature_algorithms, array(u16, tls.SignatureScheme, .{
        .ecdsa_secp256r1_sha256,
        .ecdsa_secp384r1_sha384,
        .rsa_pkcs1_sha256,
        .rsa_pkcs1_sha384,
        .rsa_pkcs1_sha512,
        .rsa_pss_rsae_sha256,
        .rsa_pss_rsae_sha384,
        .rsa_pss_rsae_sha512,
        .rsa_pss_pss_sha256,
        .rsa_pss_pss_sha384,
        .rsa_pss_pss_sha512,
        .rsa_pkcs1_sha1,
        .ed25519,
    })) ++ tls.extension(.supported_groups, array(u16, tls.NamedGroup, .{
        .x25519_ml_kem768,
        .secp256r1,
        .secp384r1,
        .x25519,
    })) ++ tls.extension(.psk_key_exchange_modes, array(u8, tls.PskKeyExchangeMode, .{
        .psk_dhe_ke,
    })) ++ tls.extension(.key_share, array(
        u16,
        u8,
        int(u16, @intFromEnum(tls.NamedGroup.x25519_ml_kem768)) ++
            array(u16, u8, key_share.ml_kem768_kp.public_key.toBytes() ++ key_share.x25519_kp.public_key) ++
            int(u16, @intFromEnum(tls.NamedGroup.secp256r1)) ++
            array(u16, u8, key_share.secp256r1_kp.public_key.toUncompressedSec1()) ++
            int(u16, @intFromEnum(tls.NamedGroup.secp384r1)) ++
            array(u16, u8, key_share.secp384r1_kp.public_key.toUncompressedSec1()) ++
            int(u16, @intFromEnum(tls.NamedGroup.x25519)) ++
            array(u16, u8, key_share.x25519_kp.public_key),
    ));
    const server_name_extension = int(u16, @intFromEnum(tls.ExtensionType.server_name)) ++
        int(u16, 2 + 1 + 2 + host_len) ++ // byte length of this extension payload
        int(u16, 1 + 2 + host_len) ++ // server_name_list byte count
        .{0x00} ++ // name_type
        int(u16, host_len);
    const server_name_extension_len = switch (options.host) {
        .no_verification => 0,
        .explicit => server_name_extension.len + host_len,
    };

    const extensions_header =
        int(u16, @intCast(extensions_payload.len + server_name_extension_len)) ++
        extensions_payload ++
        server_name_extension;

    const client_hello =
        int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
        client_hello_rand ++
        [1]u8{32} ++ legacy_session_id ++
        cipher_suites ++
        array(u8, tls.CompressionMethod, .{.null}) ++
        extensions_header;

    const out_handshake = .{@intFromEnum(tls.HandshakeType.client_hello)} ++
        int(u24, @intCast(client_hello.len - server_name_extension.len + server_name_extension_len)) ++
        client_hello;

    const cleartext_header_buf = .{@intFromEnum(tls.ContentType.handshake)} ++
        int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_0)) ++
        int(u16, @intCast(out_handshake.len - server_name_extension.len + server_name_extension_len)) ++
        out_handshake;
    const cleartext_header = switch (options.host) {
        .no_verification => cleartext_header_buf[0 .. cleartext_header_buf.len - server_name_extension.len],
        .explicit => &cleartext_header_buf,
    };

    {
        var iovecs = [_]std.posix.iovec_const{
            .{ .base = cleartext_header.ptr, .len = cleartext_header.len },
            .{ .base = host.ptr, .len = host.len },
        };
        try stream.writevAll(iovecs[0..if (host.len == 0) 1 else 2]);
    }

    var tls_version: tls.ProtocolVersion = undefined;
    // These are used for two purposes:
    // * Detect whether a certificate is the first one presented, in which case
    //   we need to verify the host name.
    var cert_index: usize = 0;
    // * Flip back and forth between the two cleartext buffers in order to keep
    //   the previous certificate in memory so that it can be verified by the
    //   next one.
    var cert_buf_index: usize = 0;
    var write_seq: u64 = 0;
    var read_seq: u64 = 0;
    var prev_cert: Certificate.Parsed = undefined;
    const CipherState = enum {
        /// No cipher is in use
        cleartext,
        /// Handshake cipher is in use
        handshake,
        /// Application cipher is in use
        application,
    };
    var pending_cipher_state: CipherState = .cleartext;
    var cipher_state = pending_cipher_state;
    const HandshakeState = enum {
        /// In this state we expect only a server hello message.
        hello,
        /// In this state we expect only an encrypted_extensions message.
        encrypted_extensions,
        /// In this state we expect certificate handshake messages.
        certificate,
        /// In this state we expect certificate or certificate_verify messages.
        /// certificate messages are ignored since the trust chain is already
        /// established.
        trust_chain_established,
        /// In this state, we expect only the server_hello_done handshake message.
        server_hello_done,
        /// In this state, we expect only the finished handshake message.
        finished,
    };
    var handshake_state: HandshakeState = .hello;
    var handshake_cipher: tls.HandshakeCipher = undefined;
    var main_cert_pub_key: CertificatePublicKey = undefined;
    const now_sec = std.time.timestamp();

    var cleartext_fragment_start: usize = 0;
    var cleartext_fragment_end: usize = 0;
    var cleartext_bufs: [2][tls.max_ciphertext_inner_record_len]u8 = undefined;
    var handshake_buffer: [tls.max_ciphertext_record_len]u8 = undefined;
    var d: tls.Decoder = .{ .buf = &handshake_buffer };
    fragment: while (true) {
        try d.readAtLeastOurAmt(stream, tls.record_header_len);
        const record_header = d.buf[d.idx..][0..tls.record_header_len];
        const record_ct = d.decode(tls.ContentType);
        d.skip(2); // legacy_version
        const record_len = d.decode(u16);
        try d.readAtLeast(stream, record_len);
        var record_decoder = try d.sub(record_len);
        var ctd, const ct = content: switch (cipher_state) {
            .cleartext => .{ record_decoder, record_ct },
            .handshake => {
                std.debug.assert(tls_version == .tls_1_3);
                if (record_ct != .application_data) return error.TlsUnexpectedMessage;
                try record_decoder.ensure(record_len);
                const cleartext_buf = &cleartext_bufs[cert_buf_index % 2];
                switch (handshake_cipher) {
                    inline else => |*p| {
                        const pv = &p.version.tls_1_3;
                        const P = @TypeOf(p.*).A;
                        if (record_len < P.AEAD.tag_length) return error.TlsRecordOverflow;
                        const ciphertext = record_decoder.slice(record_len - P.AEAD.tag_length);
                        const cleartext_fragment_buf = cleartext_buf[cleartext_fragment_end..];
                        if (ciphertext.len > cleartext_fragment_buf.len) return error.TlsRecordOverflow;
                        const cleartext = cleartext_fragment_buf[0..ciphertext.len];
                        const auth_tag = record_decoder.array(P.AEAD.tag_length).*;
                        const nonce = nonce: {
                            const V = @Vector(P.AEAD.nonce_length, u8);
                            const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                            const operand: V = pad ++ @as([8]u8, @bitCast(big(read_seq)));
                            break :nonce @as(V, pv.server_handshake_iv) ^ operand;
                        };
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag, record_header, nonce, pv.server_handshake_key) catch
                            return error.TlsBadRecordMac;
                        cleartext_fragment_end += std.mem.trimRight(u8, cleartext, "\x00").len;
                    },
                }
                read_seq += 1;
                cleartext_fragment_end -= 1;
                const ct: tls.ContentType = @enumFromInt(cleartext_buf[cleartext_fragment_end]);
                if (ct != .handshake) return error.TlsUnexpectedMessage;
                break :content .{ tls.Decoder.fromTheirSlice(@constCast(cleartext_buf[cleartext_fragment_start..cleartext_fragment_end])), ct };
            },
            .application => {
                std.debug.assert(tls_version == .tls_1_2);
                if (record_ct != .handshake) return error.TlsUnexpectedMessage;
                try record_decoder.ensure(record_len);
                const cleartext_buf = &cleartext_bufs[cert_buf_index % 2];
                switch (handshake_cipher) {
                    inline else => |*p| {
                        const pv = &p.version.tls_1_2;
                        const P = @TypeOf(p.*).A;
                        if (record_len < P.record_iv_length + P.mac_length) return error.TlsRecordOverflow;
                        const message_len: u16 = record_len - P.record_iv_length - P.mac_length;
                        const cleartext_fragment_buf = cleartext_buf[cleartext_fragment_end..];
                        if (message_len > cleartext_fragment_buf.len) return error.TlsRecordOverflow;
                        const cleartext = cleartext_fragment_buf[0..message_len];
                        const ad = std.mem.toBytes(big(read_seq)) ++
                            record_header[0 .. 1 + 2] ++
                            std.mem.toBytes(big(message_len));
                        const record_iv = record_decoder.array(P.record_iv_length).*;
                        const masked_read_seq = read_seq &
                            comptime std.math.shl(u64, std.math.maxInt(u64), 8 * P.record_iv_length);
                        const nonce: [P.AEAD.nonce_length]u8 = nonce: {
                            const V = @Vector(P.AEAD.nonce_length, u8);
                            const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                            const operand: V = pad ++ @as([8]u8, @bitCast(big(masked_read_seq)));
                            break :nonce @as(V, pv.app_cipher.server_write_IV ++ record_iv) ^ operand;
                        };
                        const ciphertext = record_decoder.slice(message_len);
                        const auth_tag = record_decoder.array(P.mac_length);
                        P.AEAD.decrypt(cleartext, ciphertext, auth_tag.*, ad, nonce, pv.app_cipher.server_write_key) catch return error.TlsBadRecordMac;
                        cleartext_fragment_end += message_len;
                    },
                }
                read_seq += 1;
                break :content .{ tls.Decoder.fromTheirSlice(cleartext_buf[cleartext_fragment_start..cleartext_fragment_end]), record_ct };
            },
        };
        switch (ct) {
            .alert => {
                ctd.ensure(2) catch continue :fragment;
                const level = ctd.decode(tls.AlertLevel);
                const desc = ctd.decode(tls.AlertDescription);
                _ = level;

                // if this isn't a error alert, then it's a closure alert, which makes no sense in a handshake
                try desc.toError();
                // TODO: handle server-side closures
                return error.TlsUnexpectedMessage;
            },
            .change_cipher_spec => {
                ctd.ensure(1) catch continue :fragment;
                if (ctd.decode(tls.ChangeCipherSpecType) != .change_cipher_spec) return error.TlsIllegalParameter;
                cipher_state = pending_cipher_state;
            },
            .handshake => while (true) {
                ctd.ensure(4) catch continue :fragment;
                const handshake_type = ctd.decode(tls.HandshakeType);
                const handshake_len = ctd.decode(u24);
                var hsd = ctd.sub(handshake_len) catch continue :fragment;
                const wrapped_handshake = ctd.buf[ctd.idx - handshake_len - 4 .. ctd.idx];
                switch (handshake_type) {
                    .server_hello => {
                        if (cipher_state != .cleartext) return error.TlsUnexpectedMessage;
                        if (handshake_state != .hello) return error.TlsUnexpectedMessage;
                        try hsd.ensure(2 + 32 + 1);
                        const legacy_version = hsd.decode(u16);
                        @memcpy(&server_hello_rand, hsd.array(32));
                        if (mem.eql(u8, &server_hello_rand, &tls.hello_retry_request_sequence)) {
                            // This is a HelloRetryRequest message. This client implementation
                            // does not expect to get one.
                            return error.TlsUnexpectedMessage;
                        }
                        const legacy_session_id_echo_len = hsd.decode(u8);
                        try hsd.ensure(legacy_session_id_echo_len + 2 + 1);
                        const legacy_session_id_echo = hsd.slice(legacy_session_id_echo_len);
                        const cipher_suite_tag = hsd.decode(tls.CipherSuite);
                        hsd.skip(1); // legacy_compression_method
                        var supported_version: ?u16 = null;
                        if (!hsd.eof()) {
                            try hsd.ensure(2);
                            const extensions_size = hsd.decode(u16);
                            var all_extd = try hsd.sub(extensions_size);
                            while (!all_extd.eof()) {
                                try all_extd.ensure(2 + 2);
                                const et = all_extd.decode(tls.ExtensionType);
                                const ext_size = all_extd.decode(u16);
                                var extd = try all_extd.sub(ext_size);
                                switch (et) {
                                    .supported_versions => {
                                        if (supported_version) |_| return error.TlsIllegalParameter;
                                        try extd.ensure(2);
                                        supported_version = extd.decode(u16);
                                    },
                                    .key_share => {
                                        if (key_share.getSharedSecret()) |_| return error.TlsIllegalParameter;
                                        try extd.ensure(4);
                                        const named_group = extd.decode(tls.NamedGroup);
                                        const key_size = extd.decode(u16);
                                        try extd.ensure(key_size);
                                        try key_share.exchange(named_group, extd.slice(key_size));
                                    },
                                    else => {},
                                }
                            }
                        }

                        tls_version = @enumFromInt(supported_version orelse legacy_version);
                        switch (tls_version) {
                            .tls_1_3 => if (!mem.eql(u8, legacy_session_id_echo, &legacy_session_id)) return error.TlsIllegalParameter,
                            .tls_1_2 => if (mem.eql(u8, server_hello_rand[24..31], "DOWNGRD") and
                                server_hello_rand[31] >> 1 == 0x00) return error.TlsIllegalParameter,
                            else => return error.TlsIllegalParameter,
                        }

                        switch (cipher_suite_tag) {
                            inline .AES_128_GCM_SHA256,
                            .AES_256_GCM_SHA384,
                            .CHACHA20_POLY1305_SHA256,
                            .AEGIS_256_SHA512,
                            .AEGIS_128L_SHA256,

                            .ECDHE_RSA_WITH_AES_128_GCM_SHA256,
                            .ECDHE_RSA_WITH_AES_256_GCM_SHA384,
                            .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
                            => |tag| {
                                handshake_cipher = @unionInit(tls.HandshakeCipher, @tagName(tag.with()), .{
                                    .transcript_hash = .init(.{}),
                                    .version = undefined,
                                });
                                const p = &@field(handshake_cipher, @tagName(tag.with()));
                                p.transcript_hash.update(cleartext_header[tls.record_header_len..]); // Client Hello part 1
                                p.transcript_hash.update(host); // Client Hello part 2
                                p.transcript_hash.update(wrapped_handshake);
                            },

                            else => return error.TlsIllegalParameter,
                        }
                        switch (tls_version) {
                            .tls_1_3 => {
                                switch (cipher_suite_tag) {
                                    inline .AES_128_GCM_SHA256,
                                    .AES_256_GCM_SHA384,
                                    .CHACHA20_POLY1305_SHA256,
                                    .AEGIS_256_SHA512,
                                    .AEGIS_128L_SHA256,
                                    => |tag| {
                                        const sk = key_share.getSharedSecret() orelse return error.TlsIllegalParameter;
                                        const p = &@field(handshake_cipher, @tagName(tag.with()));
                                        const P = @TypeOf(p.*).A;
                                        const hello_hash = p.transcript_hash.peek();
                                        const zeroes = [1]u8{0} ** P.Hash.digest_length;
                                        const early_secret = P.Hkdf.extract(&[1]u8{0}, &zeroes);
                                        const empty_hash = tls.emptyHash(P.Hash);
                                        p.version = .{ .tls_1_3 = undefined };
                                        const pv = &p.version.tls_1_3;
                                        const hs_derived_secret = hkdfExpandLabel(P.Hkdf, early_secret, "derived", &empty_hash, P.Hash.digest_length);
                                        pv.handshake_secret = P.Hkdf.extract(&hs_derived_secret, sk);
                                        const ap_derived_secret = hkdfExpandLabel(P.Hkdf, pv.handshake_secret, "derived", &empty_hash, P.Hash.digest_length);
                                        pv.master_secret = P.Hkdf.extract(&ap_derived_secret, &zeroes);
                                        const client_secret = hkdfExpandLabel(P.Hkdf, pv.handshake_secret, "c hs traffic", &hello_hash, P.Hash.digest_length);
                                        const server_secret = hkdfExpandLabel(P.Hkdf, pv.handshake_secret, "s hs traffic", &hello_hash, P.Hash.digest_length);
                                        if (options.ssl_key_log_file) |key_log_file| logSecrets(key_log_file, .{
                                            .client_random = &client_hello_rand,
                                        }, .{
                                            .SERVER_HANDSHAKE_TRAFFIC_SECRET = &server_secret,
                                            .CLIENT_HANDSHAKE_TRAFFIC_SECRET = &client_secret,
                                        });
                                        pv.client_finished_key = hkdfExpandLabel(P.Hkdf, client_secret, "finished", "", P.Hmac.key_length);
                                        pv.server_finished_key = hkdfExpandLabel(P.Hkdf, server_secret, "finished", "", P.Hmac.key_length);
                                        pv.client_handshake_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length);
                                        pv.server_handshake_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length);
                                        pv.client_handshake_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length);
                                        pv.server_handshake_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length);
                                    },
                                    else => return error.TlsIllegalParameter,
                                }
                                pending_cipher_state = .handshake;
                                handshake_state = .encrypted_extensions;
                            },
                            .tls_1_2 => switch (cipher_suite_tag) {
                                .ECDHE_RSA_WITH_AES_128_GCM_SHA256,
                                .ECDHE_RSA_WITH_AES_256_GCM_SHA384,
                                .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
                                => handshake_state = .certificate,
                                else => return error.TlsIllegalParameter,
                            },
                            else => return error.TlsIllegalParameter,
                        }
                    },
                    .encrypted_extensions => {
                        if (tls_version != .tls_1_3) return error.TlsUnexpectedMessage;
                        if (cipher_state != .handshake) return error.TlsUnexpectedMessage;
                        if (handshake_state != .encrypted_extensions) return error.TlsUnexpectedMessage;
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
                        handshake_state = .certificate;
                    },
                    .certificate => cert: {
                        if (cipher_state == .application) return error.TlsUnexpectedMessage;
                        switch (handshake_state) {
                            .certificate => {},
                            .trust_chain_established => break :cert,
                            else => return error.TlsUnexpectedMessage,
                        }
                        switch (handshake_cipher) {
                            inline else => |*p| p.transcript_hash.update(wrapped_handshake),
                        }

                        switch (tls_version) {
                            .tls_1_3 => {
                                try hsd.ensure(1 + 3);
                                const cert_req_ctx_len = hsd.decode(u8);
                                if (cert_req_ctx_len != 0) return error.TlsIllegalParameter;
                            },
                            .tls_1_2 => try hsd.ensure(3),
                            else => unreachable,
                        }
                        const certs_size = hsd.decode(u24);
                        var certs_decoder = try hsd.sub(certs_size);
                        while (!certs_decoder.eof()) {
                            try certs_decoder.ensure(3);
                            const cert_size = certs_decoder.decode(u24);
                            const certd = try certs_decoder.sub(cert_size);

                            if (tls_version == .tls_1_3) {
                                try certs_decoder.ensure(2);
                                const total_ext_size = certs_decoder.decode(u16);
                                const all_extd = try certs_decoder.sub(total_ext_size);
                                _ = all_extd;
                            }

                            const subject_cert: Certificate = .{
                                .buffer = certd.buf,
                                .index = @intCast(certd.idx),
                            };
                            const subject = try subject_cert.parse();
                            if (cert_index == 0) {
                                // Verify the host on the first certificate.
                                switch (options.host) {
                                    .no_verification => {},
                                    .explicit => try subject.verifyHostName(host),
                                }

                                // Keep track of the public key for the
                                // certificate_verify message later.
                                try main_cert_pub_key.init(subject.pub_key_algo, subject.pubKey());
                            } else {
                                try prev_cert.verify(subject, now_sec);
                            }

                            switch (options.ca) {
                                .no_verification => {
                                    handshake_state = .trust_chain_established;
                                    break :cert;
                                },
                                .self_signed => {
                                    try subject.verify(subject, now_sec);
                                    handshake_state = .trust_chain_established;
                                    break :cert;
                                },
                                .bundle => |ca_bundle| if (ca_bundle.verify(subject, now_sec)) |_| {
                                    handshake_state = .trust_chain_established;
                                    break :cert;
                                } else |err| switch (err) {
                                    error.CertificateIssuerNotFound => {},
                                    else => |e| return e,
                                },
                            }

                            prev_cert = subject;
                            cert_index += 1;
                        }
                        cert_buf_index += 1;
                    },
                    .server_key_exchange => {
                        if (tls_version != .tls_1_2) return error.TlsUnexpectedMessage;
                        if (cipher_state != .cleartext) return error.TlsUnexpectedMessage;
                        switch (handshake_state) {
                            .trust_chain_established => {},
                            .certificate => return error.TlsCertificateNotVerified,
                            else => return error.TlsUnexpectedMessage,
                        }

                        switch (handshake_cipher) {
                            inline else => |*p| p.transcript_hash.update(wrapped_handshake),
                        }
                        try hsd.ensure(1 + 2 + 1);
                        const curve_type = hsd.decode(u8);
                        if (curve_type != 0x03) return error.TlsIllegalParameter; // named_curve
                        const named_group = hsd.decode(tls.NamedGroup);
                        const key_size = hsd.decode(u8);
                        try hsd.ensure(key_size);
                        const server_pub_key = hsd.slice(key_size);
                        try main_cert_pub_key.verifySignature(&hsd, &.{ &client_hello_rand, &server_hello_rand, hsd.buf[0..hsd.idx] });
                        try key_share.exchange(named_group, server_pub_key);
                        handshake_state = .server_hello_done;
                    },
                    .server_hello_done => {
                        if (tls_version != .tls_1_2) return error.TlsUnexpectedMessage;
                        if (cipher_state != .cleartext) return error.TlsUnexpectedMessage;
                        if (handshake_state != .server_hello_done) return error.TlsUnexpectedMessage;

                        const client_key_exchange_msg = .{@intFromEnum(tls.ContentType.handshake)} ++
                            int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                            array(u16, u8, .{@intFromEnum(tls.HandshakeType.client_key_exchange)} ++
                            array(u24, u8, array(u8, u8, key_share.secp256r1_kp.public_key.toUncompressedSec1())));
                        const client_change_cipher_spec_msg = .{@intFromEnum(tls.ContentType.change_cipher_spec)} ++
                            int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                            array(u16, tls.ChangeCipherSpecType, .{.change_cipher_spec});
                        const pre_master_secret = key_share.getSharedSecret().?;
                        switch (handshake_cipher) {
                            inline else => |*p| {
                                const P = @TypeOf(p.*).A;
                                p.transcript_hash.update(wrapped_handshake);
                                p.transcript_hash.update(client_key_exchange_msg[tls.record_header_len..]);
                                const master_secret = hmacExpandLabel(P.Hmac, pre_master_secret, &.{
                                    "master secret",
                                    &client_hello_rand,
                                    &server_hello_rand,
                                }, 48);
                                if (options.ssl_key_log_file) |key_log_file| logSecrets(key_log_file, .{
                                    .client_random = &client_hello_rand,
                                }, .{
                                    .CLIENT_RANDOM = &master_secret,
                                });
                                const key_block = hmacExpandLabel(
                                    P.Hmac,
                                    &master_secret,
                                    &.{ "key expansion", &server_hello_rand, &client_hello_rand },
                                    @sizeOf(P.Tls_1_2),
                                );
                                const client_verify_cleartext = .{@intFromEnum(tls.HandshakeType.finished)} ++
                                    array(u24, u8, hmacExpandLabel(
                                    P.Hmac,
                                    &master_secret,
                                    &.{ "client finished", &p.transcript_hash.peek() },
                                    P.verify_data_length,
                                ));
                                p.transcript_hash.update(&client_verify_cleartext);
                                p.version = .{ .tls_1_2 = .{
                                    .expected_server_verify_data = hmacExpandLabel(
                                        P.Hmac,
                                        &master_secret,
                                        &.{ "server finished", &p.transcript_hash.finalResult() },
                                        P.verify_data_length,
                                    ),
                                    .app_cipher = std.mem.bytesToValue(P.Tls_1_2, &key_block),
                                } };
                                const pv = &p.version.tls_1_2;
                                const nonce: [P.AEAD.nonce_length]u8 = nonce: {
                                    const V = @Vector(P.AEAD.nonce_length, u8);
                                    const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                                    const operand: V = pad ++ @as([8]u8, @bitCast(big(write_seq)));
                                    break :nonce @as(V, pv.app_cipher.client_write_IV ++ pv.app_cipher.client_salt) ^ operand;
                                };
                                var client_verify_msg = .{@intFromEnum(tls.ContentType.handshake)} ++
                                    int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                                    array(u16, u8, nonce[P.fixed_iv_length..].* ++
                                    @as([client_verify_cleartext.len + P.mac_length]u8, undefined));
                                P.AEAD.encrypt(
                                    client_verify_msg[client_verify_msg.len - P.mac_length -
                                        client_verify_cleartext.len ..][0..client_verify_cleartext.len],
                                    client_verify_msg[client_verify_msg.len - P.mac_length ..][0..P.mac_length],
                                    &client_verify_cleartext,
                                    std.mem.toBytes(big(write_seq)) ++ client_verify_msg[0 .. 1 + 2] ++ int(u16, client_verify_cleartext.len),
                                    nonce,
                                    pv.app_cipher.client_write_key,
                                );
                                const all_msgs = client_key_exchange_msg ++ client_change_cipher_spec_msg ++ client_verify_msg;
                                var all_msgs_vec = [_]std.posix.iovec_const{
                                    .{ .base = &all_msgs, .len = all_msgs.len },
                                };
                                try stream.writevAll(&all_msgs_vec);
                            },
                        }
                        write_seq += 1;
                        pending_cipher_state = .application;
                        handshake_state = .finished;
                    },
                    .certificate_verify => {
                        if (tls_version != .tls_1_3) return error.TlsUnexpectedMessage;
                        if (cipher_state != .handshake) return error.TlsUnexpectedMessage;
                        switch (handshake_state) {
                            .trust_chain_established => {},
                            .certificate => return error.TlsCertificateNotVerified,
                            else => return error.TlsUnexpectedMessage,
                        }
                        switch (handshake_cipher) {
                            inline else => |*p| {
                                try main_cert_pub_key.verifySignature(&hsd, &.{
                                    " " ** 64 ++ "TLS 1.3, server CertificateVerify\x00",
                                    &p.transcript_hash.peek(),
                                });
                                p.transcript_hash.update(wrapped_handshake);
                            },
                        }
                        handshake_state = .finished;
                    },
                    .finished => {
                        if (cipher_state == .cleartext) return error.TlsUnexpectedMessage;
                        if (handshake_state != .finished) return error.TlsUnexpectedMessage;
                        // This message is to trick buggy proxies into behaving correctly.
                        const client_change_cipher_spec_msg = .{@intFromEnum(tls.ContentType.change_cipher_spec)} ++
                            int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                            array(u16, tls.ChangeCipherSpecType, .{.change_cipher_spec});
                        const app_cipher = app_cipher: switch (handshake_cipher) {
                            inline else => |*p, tag| switch (tls_version) {
                                .tls_1_3 => {
                                    const pv = &p.version.tls_1_3;
                                    const P = @TypeOf(p.*).A;
                                    try hsd.ensure(P.Hmac.mac_length);
                                    const finished_digest = p.transcript_hash.peek();
                                    p.transcript_hash.update(wrapped_handshake);
                                    const expected_server_verify_data = tls.hmac(P.Hmac, &finished_digest, pv.server_finished_key);
                                    if (!std.crypto.timing_safe.eql([P.Hmac.mac_length]u8, expected_server_verify_data, hsd.array(P.Hmac.mac_length).*)) return error.TlsDecryptError;
                                    const handshake_hash = p.transcript_hash.finalResult();
                                    const verify_data = tls.hmac(P.Hmac, &handshake_hash, pv.client_finished_key);
                                    const out_cleartext = .{@intFromEnum(tls.HandshakeType.finished)} ++
                                        array(u24, u8, verify_data) ++
                                        .{@intFromEnum(tls.ContentType.handshake)};

                                    const wrapped_len = out_cleartext.len + P.AEAD.tag_length;

                                    var finished_msg = .{@intFromEnum(tls.ContentType.application_data)} ++
                                        int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                                        array(u16, u8, @as([wrapped_len]u8, undefined));

                                    const ad = finished_msg[0..tls.record_header_len];
                                    const ciphertext = finished_msg[tls.record_header_len..][0..out_cleartext.len];
                                    const auth_tag = finished_msg[finished_msg.len - P.AEAD.tag_length ..];
                                    const nonce = pv.client_handshake_iv;
                                    P.AEAD.encrypt(ciphertext, auth_tag, &out_cleartext, ad, nonce, pv.client_handshake_key);

                                    const all_msgs = client_change_cipher_spec_msg ++ finished_msg;
                                    var all_msgs_vec = [_]std.posix.iovec_const{
                                        .{ .base = &all_msgs, .len = all_msgs.len },
                                    };
                                    try stream.writevAll(&all_msgs_vec);

                                    const client_secret = hkdfExpandLabel(P.Hkdf, pv.master_secret, "c ap traffic", &handshake_hash, P.Hash.digest_length);
                                    const server_secret = hkdfExpandLabel(P.Hkdf, pv.master_secret, "s ap traffic", &handshake_hash, P.Hash.digest_length);
                                    if (options.ssl_key_log_file) |key_log_file| logSecrets(key_log_file, .{
                                        .counter = key_seq,
                                        .client_random = &client_hello_rand,
                                    }, .{
                                        .SERVER_TRAFFIC_SECRET = &server_secret,
                                        .CLIENT_TRAFFIC_SECRET = &client_secret,
                                    });
                                    key_seq += 1;
                                    break :app_cipher @unionInit(tls.ApplicationCipher, @tagName(tag), .{ .tls_1_3 = .{
                                        .client_secret = client_secret,
                                        .server_secret = server_secret,
                                        .client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length),
                                        .server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length),
                                        .client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length),
                                        .server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length),
                                    } });
                                },
                                .tls_1_2 => {
                                    const pv = &p.version.tls_1_2;
                                    const P = @TypeOf(p.*).A;
                                    try hsd.ensure(P.verify_data_length);
                                    if (!std.crypto.timing_safe.eql([P.verify_data_length]u8, pv.expected_server_verify_data, hsd.array(P.verify_data_length).*)) return error.TlsDecryptError;
                                    break :app_cipher @unionInit(tls.ApplicationCipher, @tagName(tag), .{ .tls_1_2 = pv.app_cipher });
                                },
                                else => unreachable,
                            },
                        };
                        const leftover = d.rest();
                        var client: Client = .{
                            .tls_version = tls_version,
                            .read_seq = switch (tls_version) {
                                .tls_1_3 => 0,
                                .tls_1_2 => read_seq,
                                else => unreachable,
                            },
                            .write_seq = switch (tls_version) {
                                .tls_1_3 => 0,
                                .tls_1_2 => write_seq,
                                else => unreachable,
                            },
                            .partial_cleartext_idx = 0,
                            .partial_ciphertext_idx = 0,
                            .partial_ciphertext_end = @intCast(leftover.len),
                            .received_close_notify = false,
                            .allow_truncation_attacks = false,
                            .application_cipher = app_cipher,
                            .partially_read_buffer = undefined,
                            .ssl_key_log = if (options.ssl_key_log_file) |key_log_file| .{
                                .client_key_seq = key_seq,
                                .server_key_seq = key_seq,
                                .client_random = client_hello_rand,
                                .file = key_log_file,
                            } else null,
                        };
                        @memcpy(client.partially_read_buffer[0..leftover.len], leftover);
                        return client;
                    },
                    else => return error.TlsUnexpectedMessage,
                }
                if (ctd.eof()) break;
                cleartext_fragment_start = ctd.idx;
            },
            else => return error.TlsUnexpectedMessage,
        }
        cleartext_fragment_start = 0;
        cleartext_fragment_end = 0;
    }
}

/// Sends TLS-encrypted data to `stream`, which must conform to `StreamInterface`.
/// Returns the number of cleartext bytes sent, which may be fewer than `bytes.len`.
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
/// Returns the number of cleartext bytes sent, which may be fewer than `bytes.len`.
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
        inline else => |*p| switch (c.tls_version) {
            .tls_1_3 => {
                const pv = &p.tls_1_3;
                const P = @TypeOf(p.*);
                const overhead_len = tls.record_header_len + P.AEAD.tag_length + 1;
                const close_notify_alert_reserved = tls.close_notify_alert.len + overhead_len;
                while (true) {
                    const encrypted_content_len: u16 = @min(
                        bytes.len - bytes_i,
                        tls.max_ciphertext_inner_record_len,
                        ciphertext_buf.len -|
                            (close_notify_alert_reserved + overhead_len + ciphertext_end),
                    );
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
                    const ad = ciphertext_buf[ciphertext_end..][0..tls.record_header_len];
                    ad.* = .{@intFromEnum(tls.ContentType.application_data)} ++
                        int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                        int(u16, ciphertext_len + P.AEAD.tag_length);
                    ciphertext_end += ad.len;
                    const ciphertext = ciphertext_buf[ciphertext_end..][0..ciphertext_len];
                    ciphertext_end += ciphertext_len;
                    const auth_tag = ciphertext_buf[ciphertext_end..][0..P.AEAD.tag_length];
                    ciphertext_end += auth_tag.len;
                    const nonce = nonce: {
                        const V = @Vector(P.AEAD.nonce_length, u8);
                        const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                        const operand: V = pad ++ std.mem.toBytes(big(c.write_seq));
                        break :nonce @as(V, pv.client_iv) ^ operand;
                    };
                    P.AEAD.encrypt(ciphertext, auth_tag, cleartext, ad, nonce, pv.client_key);
                    c.write_seq += 1; // TODO send key_update on overflow

                    const record = ciphertext_buf[record_start..ciphertext_end];
                    iovecs[iovec_end] = .{
                        .base = record.ptr,
                        .len = record.len,
                    };
                    iovec_end += 1;
                }
            },
            .tls_1_2 => {
                const pv = &p.tls_1_2;
                const P = @TypeOf(p.*);
                const overhead_len = tls.record_header_len + P.record_iv_length + P.mac_length;
                const close_notify_alert_reserved = tls.close_notify_alert.len + overhead_len;
                while (true) {
                    const message_len: u16 = @min(
                        bytes.len - bytes_i,
                        tls.max_ciphertext_inner_record_len,
                        ciphertext_buf.len -|
                            (close_notify_alert_reserved + overhead_len + ciphertext_end),
                    );
                    if (message_len == 0) return .{
                        .iovec_end = iovec_end,
                        .ciphertext_end = ciphertext_end,
                        .overhead_len = overhead_len,
                    };

                    @memcpy(cleartext_buf[0..message_len], bytes[bytes_i..][0..message_len]);
                    bytes_i += message_len;
                    const cleartext = cleartext_buf[0..message_len];

                    const record_start = ciphertext_end;
                    const record_header = ciphertext_buf[ciphertext_end..][0..tls.record_header_len];
                    ciphertext_end += tls.record_header_len;
                    record_header.* = .{@intFromEnum(inner_content_type)} ++
                        int(u16, @intFromEnum(tls.ProtocolVersion.tls_1_2)) ++
                        int(u16, P.record_iv_length + message_len + P.mac_length);
                    const ad = std.mem.toBytes(big(c.write_seq)) ++ record_header[0 .. 1 + 2] ++ int(u16, message_len);
                    const record_iv = ciphertext_buf[ciphertext_end..][0..P.record_iv_length];
                    ciphertext_end += P.record_iv_length;
                    const nonce: [P.AEAD.nonce_length]u8 = nonce: {
                        const V = @Vector(P.AEAD.nonce_length, u8);
                        const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                        const operand: V = pad ++ @as([8]u8, @bitCast(big(c.write_seq)));
                        break :nonce @as(V, pv.client_write_IV ++ pv.client_salt) ^ operand;
                    };
                    record_iv.* = nonce[P.fixed_iv_length..].*;
                    const ciphertext = ciphertext_buf[ciphertext_end..][0..message_len];
                    ciphertext_end += message_len;
                    const auth_tag = ciphertext_buf[ciphertext_end..][0..P.mac_length];
                    ciphertext_end += P.mac_length;
                    P.AEAD.encrypt(ciphertext, auth_tag, cleartext, ad, nonce, pv.client_write_key);
                    c.write_seq += 1; // TODO send key_update on overflow

                    const record = ciphertext_buf[record_start..ciphertext_end];
                    iovecs[iovec_end] = .{
                        .base = record.ptr,
                        .len = record.len,
                    };
                    iovec_end += 1;
                }
            },
            else => unreachable,
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

    // Recoup `partially_read_buffer` space. This is necessary because it is assumed
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
        const cleartext, const inner_ct: tls.ContentType = cleartext: switch (c.application_cipher) {
            inline else => |*p| switch (c.tls_version) {
                .tls_1_3 => {
                    const pv = &p.tls_1_3;
                    const P = @TypeOf(p.*);
                    const ad = frag[in - tls.record_header_len ..][0..tls.record_header_len];
                    const ciphertext_len = record_len - P.AEAD.tag_length;
                    const ciphertext = frag[in..][0..ciphertext_len];
                    in += ciphertext_len;
                    const auth_tag = frag[in..][0..P.AEAD.tag_length].*;
                    const nonce = nonce: {
                        const V = @Vector(P.AEAD.nonce_length, u8);
                        const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                        const operand: V = pad ++ std.mem.toBytes(big(c.read_seq));
                        break :nonce @as(V, pv.server_iv) ^ operand;
                    };
                    const out_buf = vp.peek();
                    const cleartext_buf = if (ciphertext.len <= out_buf.len)
                        out_buf
                    else
                        &cleartext_stack_buffer;
                    const cleartext = cleartext_buf[0..ciphertext.len];
                    P.AEAD.decrypt(cleartext, ciphertext, auth_tag, ad, nonce, pv.server_key) catch
                        return error.TlsBadRecordMac;
                    const msg = mem.trimRight(u8, cleartext, "\x00");
                    break :cleartext .{ msg[0 .. msg.len - 1], @enumFromInt(msg[msg.len - 1]) };
                },
                .tls_1_2 => {
                    const pv = &p.tls_1_2;
                    const P = @TypeOf(p.*);
                    const message_len: u16 = record_len - P.record_iv_length - P.mac_length;
                    const ad = std.mem.toBytes(big(c.read_seq)) ++
                        frag[in - tls.record_header_len ..][0 .. 1 + 2] ++
                        std.mem.toBytes(big(message_len));
                    const record_iv = frag[in..][0..P.record_iv_length].*;
                    in += P.record_iv_length;
                    const masked_read_seq = c.read_seq &
                        comptime std.math.shl(u64, std.math.maxInt(u64), 8 * P.record_iv_length);
                    const nonce: [P.AEAD.nonce_length]u8 = nonce: {
                        const V = @Vector(P.AEAD.nonce_length, u8);
                        const pad = [1]u8{0} ** (P.AEAD.nonce_length - 8);
                        const operand: V = pad ++ @as([8]u8, @bitCast(big(masked_read_seq)));
                        break :nonce @as(V, pv.server_write_IV ++ record_iv) ^ operand;
                    };
                    const ciphertext = frag[in..][0..message_len];
                    in += message_len;
                    const auth_tag = frag[in..][0..P.mac_length].*;
                    in += P.mac_length;
                    const out_buf = vp.peek();
                    const cleartext_buf = if (message_len <= out_buf.len)
                        out_buf
                    else
                        &cleartext_stack_buffer;
                    const cleartext = cleartext_buf[0..ciphertext.len];
                    P.AEAD.decrypt(cleartext, ciphertext, auth_tag, ad, nonce, pv.server_write_key) catch
                        return error.TlsBadRecordMac;
                    break :cleartext .{ cleartext, ct };
                },
                else => unreachable,
            },
        };
        c.read_seq = try std.math.add(u64, c.read_seq, 1);
        switch (inner_ct) {
            .alert => {
                if (cleartext.len != 2) return error.TlsDecodeError;
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
                    if (next_handshake_i > cleartext.len)
                        return error.TlsBadLength;
                    const handshake = cleartext[ct_i..next_handshake_i];
                    switch (handshake_type) {
                        .new_session_ticket => {
                            // This client implementation ignores new session tickets.
                        },
                        .key_update => {
                            switch (c.application_cipher) {
                                inline else => |*p| {
                                    const pv = &p.tls_1_3;
                                    const P = @TypeOf(p.*);
                                    const server_secret = hkdfExpandLabel(P.Hkdf, pv.server_secret, "traffic upd", "", P.Hash.digest_length);
                                    if (c.ssl_key_log) |*key_log| logSecrets(key_log.file, .{
                                        .counter = key_log.serverCounter(),
                                        .client_random = &key_log.client_random,
                                    }, .{
                                        .SERVER_TRAFFIC_SECRET = &server_secret,
                                    });
                                    pv.server_secret = server_secret;
                                    pv.server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length);
                                    pv.server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length);
                                },
                            }
                            c.read_seq = 0;

                            switch (@as(tls.KeyUpdateRequest, @enumFromInt(handshake[0]))) {
                                .update_requested => {
                                    switch (c.application_cipher) {
                                        inline else => |*p| {
                                            const pv = &p.tls_1_3;
                                            const P = @TypeOf(p.*);
                                            const client_secret = hkdfExpandLabel(P.Hkdf, pv.client_secret, "traffic upd", "", P.Hash.digest_length);
                                            if (c.ssl_key_log) |*key_log| logSecrets(key_log.file, .{
                                                .counter = key_log.clientCounter(),
                                                .client_random = &key_log.client_random,
                                            }, .{
                                                .CLIENT_TRAFFIC_SECRET = &client_secret,
                                            });
                                            pv.client_secret = client_secret;
                                            pv.client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length);
                                            pv.client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length);
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
                    if (ct_i >= cleartext.len) break;
                }
            },
            .application_data => {
                // Determine whether the output buffer or a stack
                // buffer was used for storing the cleartext.
                if (cleartext.ptr == &cleartext_stack_buffer) {
                    // Stack buffer was used, so we must copy to the output buffer.
                    if (c.partial_ciphertext_idx > c.partial_cleartext_idx) {
                        // We have already run out of room in iovecs. Continue
                        // appending to `partially_read_buffer`.
                        @memcpy(
                            c.partially_read_buffer[c.partial_ciphertext_idx..][0..cleartext.len],
                            cleartext,
                        );
                        c.partial_ciphertext_idx = @intCast(c.partial_ciphertext_idx + cleartext.len);
                    } else {
                        const amt = vp.put(cleartext);
                        if (amt < cleartext.len) {
                            const rest = cleartext[amt..];
                            c.partial_cleartext_idx = 0;
                            c.partial_ciphertext_idx = @intCast(rest.len);
                            @memcpy(c.partially_read_buffer[0..rest.len], rest);
                        }
                    }
                } else {
                    // Output buffer was used directly which means no
                    // memory copying needs to occur, and we can move
                    // on to the next ciphertext record.
                    vp.next(cleartext.len);
                }
            },
            else => return error.TlsUnexpectedMessage,
        }
        in = end;
    }
}

fn logSecrets(key_log_file: std.fs.File, context: anytype, secrets: anytype) void {
    const locked = if (key_log_file.lock(.exclusive)) |_| true else |_| false;
    defer if (locked) key_log_file.unlock();
    key_log_file.seekFromEnd(0) catch {};
    inline for (@typeInfo(@TypeOf(secrets)).@"struct".fields) |field| key_log_file.writer().print("{s}" ++
        (if (@hasField(@TypeOf(context), "counter")) "_{d}" else "") ++ " {x} {x}\n", .{field.name} ++
        (if (@hasField(@TypeOf(context), "counter")) .{context.counter} else .{}) ++ .{
        context.client_random,
        @field(secrets, field.name),
    }) catch {};
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

const KeyShare = struct {
    ml_kem768_kp: crypto.kem.ml_kem.MLKem768.KeyPair,
    secp256r1_kp: crypto.sign.ecdsa.EcdsaP256Sha256.KeyPair,
    secp384r1_kp: crypto.sign.ecdsa.EcdsaP384Sha384.KeyPair,
    x25519_kp: crypto.dh.X25519.KeyPair,
    sk_buf: [sk_max_len]u8,
    sk_len: std.math.IntFittingRange(0, sk_max_len),

    const sk_max_len = @max(
        crypto.dh.X25519.shared_length + crypto.kem.ml_kem.MLKem768.shared_length,
        crypto.ecc.P256.scalar.encoded_length,
        crypto.ecc.P384.scalar.encoded_length,
        crypto.dh.X25519.shared_length,
    );

    fn init(seed: [112]u8) error{IdentityElement}!KeyShare {
        return .{
            .ml_kem768_kp = .generate(),
            .secp256r1_kp = try .generateDeterministic(seed[0..32].*),
            .secp384r1_kp = try .generateDeterministic(seed[32..80].*),
            .x25519_kp = try .generateDeterministic(seed[80..112].*),
            .sk_buf = undefined,
            .sk_len = 0,
        };
    }

    fn exchange(
        ks: *KeyShare,
        named_group: tls.NamedGroup,
        server_pub_key: []const u8,
    ) error{ TlsIllegalParameter, TlsDecryptFailure }!void {
        switch (named_group) {
            .x25519_ml_kem768 => {
                const hksl = crypto.kem.ml_kem.MLKem768.ciphertext_length;
                const xksl = hksl + crypto.dh.X25519.public_length;
                if (server_pub_key.len != xksl) return error.TlsIllegalParameter;

                const hsk = ks.ml_kem768_kp.secret_key.decaps(server_pub_key[0..hksl]) catch
                    return error.TlsDecryptFailure;
                const xsk = crypto.dh.X25519.scalarmult(ks.x25519_kp.secret_key, server_pub_key[hksl..xksl].*) catch
                    return error.TlsDecryptFailure;
                @memcpy(ks.sk_buf[0..hsk.len], &hsk);
                @memcpy(ks.sk_buf[hsk.len..][0..xsk.len], &xsk);
                ks.sk_len = hsk.len + xsk.len;
            },
            .secp256r1 => {
                const PublicKey = crypto.sign.ecdsa.EcdsaP256Sha256.PublicKey;
                const pk = PublicKey.fromSec1(server_pub_key) catch return error.TlsDecryptFailure;
                const mul = pk.p.mulPublic(ks.secp256r1_kp.secret_key.bytes, .big) catch
                    return error.TlsDecryptFailure;
                const sk = mul.affineCoordinates().x.toBytes(.big);
                @memcpy(ks.sk_buf[0..sk.len], &sk);
                ks.sk_len = sk.len;
            },
            .secp384r1 => {
                const PublicKey = crypto.sign.ecdsa.EcdsaP384Sha384.PublicKey;
                const pk = PublicKey.fromSec1(server_pub_key) catch return error.TlsDecryptFailure;
                const mul = pk.p.mulPublic(ks.secp384r1_kp.secret_key.bytes, .big) catch
                    return error.TlsDecryptFailure;
                const sk = mul.affineCoordinates().x.toBytes(.big);
                @memcpy(ks.sk_buf[0..sk.len], &sk);
                ks.sk_len = sk.len;
            },
            .x25519 => {
                const ksl = crypto.dh.X25519.public_length;
                if (server_pub_key.len != ksl) return error.TlsIllegalParameter;
                const sk = crypto.dh.X25519.scalarmult(ks.x25519_kp.secret_key, server_pub_key[0..ksl].*) catch
                    return error.TlsDecryptFailure;
                @memcpy(ks.sk_buf[0..sk.len], &sk);
                ks.sk_len = sk.len;
            },
            else => return error.TlsIllegalParameter,
        }
    }

    fn getSharedSecret(ks: *const KeyShare) ?[]const u8 {
        return if (ks.sk_len > 0) ks.sk_buf[0..ks.sk_len] else null;
    }
};

fn SchemeEcdsa(comptime scheme: tls.SignatureScheme) type {
    return switch (scheme) {
        .ecdsa_secp256r1_sha256 => crypto.sign.ecdsa.EcdsaP256Sha256,
        .ecdsa_secp384r1_sha384 => crypto.sign.ecdsa.EcdsaP384Sha384,
        else => @compileError("bad scheme"),
    };
}

fn SchemeRsa(comptime scheme: tls.SignatureScheme) type {
    return switch (scheme) {
        .rsa_pkcs1_sha256,
        .rsa_pkcs1_sha384,
        .rsa_pkcs1_sha512,
        .rsa_pkcs1_sha1,
        => Certificate.rsa.PKCS1v1_5Signature,
        .rsa_pss_rsae_sha256,
        .rsa_pss_rsae_sha384,
        .rsa_pss_rsae_sha512,
        .rsa_pss_pss_sha256,
        .rsa_pss_pss_sha384,
        .rsa_pss_pss_sha512,
        => Certificate.rsa.PSSSignature,
        else => @compileError("bad scheme"),
    };
}

fn SchemeEddsa(comptime scheme: tls.SignatureScheme) type {
    return switch (scheme) {
        .ed25519 => crypto.sign.Ed25519,
        else => @compileError("bad scheme"),
    };
}

fn SchemeHash(comptime scheme: tls.SignatureScheme) type {
    return switch (scheme) {
        .rsa_pkcs1_sha256,
        .ecdsa_secp256r1_sha256,
        .rsa_pss_rsae_sha256,
        .rsa_pss_pss_sha256,
        => crypto.hash.sha2.Sha256,
        .rsa_pkcs1_sha384,
        .ecdsa_secp384r1_sha384,
        .rsa_pss_rsae_sha384,
        .rsa_pss_pss_sha384,
        => crypto.hash.sha2.Sha384,
        .rsa_pkcs1_sha512,
        .ecdsa_secp521r1_sha512,
        .rsa_pss_rsae_sha512,
        .rsa_pss_pss_sha512,
        => crypto.hash.sha2.Sha512,
        .rsa_pkcs1_sha1,
        .ecdsa_sha1,
        => crypto.hash.Sha1,
        else => @compileError("bad scheme"),
    };
}

const CertificatePublicKey = struct {
    algo: Certificate.AlgorithmCategory,
    buf: [600]u8,
    len: u16,

    fn init(
        cert_pub_key: *CertificatePublicKey,
        algo: Certificate.AlgorithmCategory,
        pub_key: []const u8,
    ) error{CertificatePublicKeyInvalid}!void {
        if (pub_key.len > cert_pub_key.buf.len) return error.CertificatePublicKeyInvalid;
        cert_pub_key.algo = algo;
        @memcpy(cert_pub_key.buf[0..pub_key.len], pub_key);
        cert_pub_key.len = @intCast(pub_key.len);
    }

    const VerifyError = error{ TlsDecodeError, TlsBadSignatureScheme, InvalidEncoding } ||
        // ecdsa
        crypto.errors.EncodingError ||
        crypto.errors.NotSquareError ||
        crypto.errors.NonCanonicalError ||
        SchemeEcdsa(.ecdsa_secp256r1_sha256).Signature.VerifyError ||
        SchemeEcdsa(.ecdsa_secp384r1_sha384).Signature.VerifyError ||
        // rsa
        error{TlsBadRsaSignatureBitCount} ||
        Certificate.rsa.PublicKey.ParseDerError ||
        Certificate.rsa.PublicKey.FromBytesError ||
        Certificate.rsa.PSSSignature.VerifyError ||
        Certificate.rsa.PKCS1v1_5Signature.VerifyError ||
        // eddsa
        SchemeEddsa(.ed25519).Signature.VerifyError;

    fn verifySignature(
        cert_pub_key: *const CertificatePublicKey,
        sigd: *tls.Decoder,
        msg: []const []const u8,
    ) VerifyError!void {
        const pub_key = cert_pub_key.buf[0..cert_pub_key.len];

        try sigd.ensure(2 + 2);
        const scheme = sigd.decode(tls.SignatureScheme);
        const sig_len = sigd.decode(u16);
        try sigd.ensure(sig_len);
        const encoded_sig = sigd.slice(sig_len);

        if (cert_pub_key.algo != @as(Certificate.AlgorithmCategory, switch (scheme) {
            .ecdsa_secp256r1_sha256,
            .ecdsa_secp384r1_sha384,
            => .X9_62_id_ecPublicKey,
            .rsa_pkcs1_sha256,
            .rsa_pkcs1_sha384,
            .rsa_pkcs1_sha512,
            .rsa_pss_rsae_sha256,
            .rsa_pss_rsae_sha384,
            .rsa_pss_rsae_sha512,
            .rsa_pkcs1_sha1,
            => .rsaEncryption,
            .rsa_pss_pss_sha256,
            .rsa_pss_pss_sha384,
            .rsa_pss_pss_sha512,
            => .rsassa_pss,
            else => return error.TlsBadSignatureScheme,
        })) return error.TlsBadSignatureScheme;

        switch (scheme) {
            inline .ecdsa_secp256r1_sha256,
            .ecdsa_secp384r1_sha384,
            => |comptime_scheme| {
                const Ecdsa = SchemeEcdsa(comptime_scheme);
                const sig = try Ecdsa.Signature.fromDer(encoded_sig);
                const key = try Ecdsa.PublicKey.fromSec1(pub_key);
                var ver = try sig.verifier(key);
                for (msg) |part| ver.update(part);
                try ver.verify();
            },
            inline .rsa_pkcs1_sha256,
            .rsa_pkcs1_sha384,
            .rsa_pkcs1_sha512,
            .rsa_pss_rsae_sha256,
            .rsa_pss_rsae_sha384,
            .rsa_pss_rsae_sha512,
            .rsa_pss_pss_sha256,
            .rsa_pss_pss_sha384,
            .rsa_pss_pss_sha512,
            .rsa_pkcs1_sha1,
            => |comptime_scheme| {
                const RsaSignature = SchemeRsa(comptime_scheme);
                const Hash = SchemeHash(comptime_scheme);
                const PublicKey = Certificate.rsa.PublicKey;
                const components = try PublicKey.parseDer(pub_key);
                const exponent = components.exponent;
                const modulus = components.modulus;
                switch (modulus.len) {
                    inline 128, 256, 384, 512 => |modulus_len| {
                        const key: PublicKey = try .fromBytes(exponent, modulus);
                        const sig = RsaSignature.fromBytes(modulus_len, encoded_sig);
                        try RsaSignature.concatVerify(modulus_len, sig, msg, key, Hash);
                    },
                    else => return error.TlsBadRsaSignatureBitCount,
                }
            },
            inline .ed25519 => |comptime_scheme| {
                const Eddsa = SchemeEddsa(comptime_scheme);
                if (encoded_sig.len != Eddsa.Signature.encoded_length) return error.InvalidEncoding;
                const sig = Eddsa.Signature.fromBytes(encoded_sig[0..Eddsa.Signature.encoded_length].*);
                if (pub_key.len != Eddsa.PublicKey.encoded_length) return error.InvalidEncoding;
                const key = try Eddsa.PublicKey.fromBytes(pub_key[0..Eddsa.PublicKey.encoded_length].*);
                var ver = try sig.verifier(key);
                for (msg) |part| ver.update(part);
                try ver.verify();
            },
            else => unreachable,
        }
    }
};

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
    array(u16, tls.CipherSuite, .{
        .AEGIS_128L_SHA256,
        .AEGIS_256_SHA512,
        .AES_128_GCM_SHA256,
        .ECDHE_RSA_WITH_AES_128_GCM_SHA256,
        .AES_256_GCM_SHA384,
        .ECDHE_RSA_WITH_AES_256_GCM_SHA384,
        .CHACHA20_POLY1305_SHA256,
        .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
    })
else
    array(u16, tls.CipherSuite, .{
        .CHACHA20_POLY1305_SHA256,
        .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
        .AEGIS_128L_SHA256,
        .AEGIS_256_SHA512,
        .AES_128_GCM_SHA256,
        .ECDHE_RSA_WITH_AES_128_GCM_SHA256,
        .AES_256_GCM_SHA384,
        .ECDHE_RSA_WITH_AES_256_GCM_SHA384,
    });

test {
    _ = StreamInterface;
}

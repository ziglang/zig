const std = @import("../std.zig");
const builtin = @import("builtin");
pub const Client = @import("tls/Client.zig");
pub const Server = @import("tls/Server.zig");
pub const Stream = @import("tls/Stream.zig");

const Tls = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const native_endian = builtin.cpu.arch.endian();
pub const ServerOptions = Server.Options;
pub const ClientOptions = Client.Options;

pub const Version = enum(u16) {
    tls_1_0 = 0x0301,
    tls_1_1 = 0x0302,
    tls_1_2 = 0x0303,
    tls_1_3 = 0x0304,
    _,
};

pub const ContentType = enum(u8) {
    invalid = 0,
    change_cipher_spec = 0x14,
    alert = 0x15,
    handshake = 0x16,
    application_data = 0x17,
    heartbeat = 0x18,
    _,
};

pub const Plaintext = struct {
    type: ContentType,
    version: Version = .tls_1_0,
    len: u16,

    pub const size = @sizeOf(ContentType) + @sizeOf(Version) + @sizeOf(u16);
    pub const max_length = 1 << 14;

    const Self = @This();

    pub fn init(bytes: [size]u8) Self {
        var stream = std.io.fixedBufferStream(&bytes);
        var reader = stream.reader();
        const ty = reader.readInt(u8, .big) catch unreachable;
        const version = reader.readInt(u16, .big) catch unreachable;
        const len = reader.readInt(u16, .big) catch unreachable;
        return .{ .type = @enumFromInt(ty), .version = @enumFromInt(version), .len = len };
    }
};

pub const HandshakeType = enum(u8) {
    /// Deprecated.
    hello_request = 0,
    client_hello = 1,
    server_hello = 2,
    /// Deprecated.
    hello_verify_request = 3,
    new_session_ticket = 4,
    end_of_early_data = 5,
    /// Deprecated.
    hello_retry_request = 6,
    encrypted_extensions = 8,
    certificate = 11,
    /// Deprecated.
    server_key_exchange = 12,
    certificate_request = 13,
    /// Deprecated.
    server_hello_done = 14,
    certificate_verify = 15,
    /// Deprecated.
    client_key_exchange = 16,
    finished = 20,
    /// Deprecated.
    certificate_url = 21,
    /// Deprecated.
    certificate_status = 22,
    /// Deprecated.
    supplemental_data = 23,
    key_update = 24,
    message_hash = 254,
    _,
};

pub const Handshake = union(HandshakeType) {
    hello_request: void,
    client_hello: ClientHello,
    server_hello: ServerHello,
    /// Deprecated.
    hello_verify_request: void,
    new_session_ticket: void,
    end_of_early_data: void,
    /// Deprecated.
    hello_retry_request: void,
    encrypted_extensions: []const Extension,
    certificate: Certificate,
    /// Deprecated.
    server_key_exchange: void,
    certificate_request: void,
    /// Deprecated.
    server_hello_done: void,
    certificate_verify: CertificateVerify,
    /// Deprecated.
    client_key_exchange: void,
    finished: []const u8,
    /// Deprecated.
    certificate_url: void,
    /// Deprecated.
    certificate_status: void,
    /// Deprecated.
    supplemental_data: void,
    key_update: KeyUpdate,
    message_hash: void,

    // If `HandshakeCipherT.encode` accepts iovecs for the message this can be moved
    // to `Stream.writeFragment` and this type can be deleted.
    pub fn write(self: @This(), stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.write(HandshakeType, self);
        switch (self) {
            .finished => |verification| {
                res += try stream.writeArray(u24, u8, verification);
            },
            inline else => |value| {
                var len: usize = 0;
                const T = @TypeOf(value);
                switch (@typeInfo(T)) {
                    .Void => {
                        res += try stream.write(u24, @intCast(len));
                    },
                    .Pointer => |info| {
                        len += stream.arrayLength(u16, info.child, value);
                        res += try stream.write(u24, @intCast(len));
                        res += try stream.writeArray(u16, info.child, value);
                    },
                    .Struct => {
                        len += stream.length(T, value);
                        res += try stream.write(u24, @intCast(len));
                        res += try stream.write(T, value);
                    },
                    .Enum => |info| {
                        len += @bitSizeOf(info.tag_type) / 8;
                        res += try stream.write(u24, @intCast(len));
                        res += try stream.write(T, value);
                    },
                    else => |t| @compileError("implement writing " ++ @tagName(t)),
                }
            },
        }
        return res;
    }

    pub const Header = struct {
        type: HandshakeType,
        len: u24,
    };
};

pub const KeyUpdate = enum(u8) {
    update_not_requested = 0,
    update_requested = 1,
    _,
};

/// A DER encoded certificate chain with the first entry being for this domain.
pub const Certificate = struct {
    context: []const u8 = "",
    entries: []const Entry,

    pub const max_context_len = 255;

    pub const Entry = struct {
        /// DER encoded
        data: []const u8,
        extensions: []const Extension = &.{},

        pub const max_data_len = 1 << 24 - 1;

        pub fn write(self: @This(), stream: *Stream) !usize {
            var res: usize = 0;
            res += try stream.writeArray(u24, u8, self.data);
            res += try stream.writeArray(u16, Extension, self.extensions);
            return res;
        }
    };

    const Self = @This();

    pub fn write(self: Self, stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.writeArray(u8, u8, self.context);
        res += try stream.writeArray(u24, Entry, self.entries);
        return res;
    }
};

pub const CertificateVerify = struct {
    algorithm: SignatureScheme,
    signature: []const u8,

    pub const max_signature_length = 1 << 16 - 1;

    pub fn write(self: @This(), stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.write(SignatureScheme, self.algorithm);
        res += try stream.writeArray(u16, u8, self.signature);
        return res;
    }
};

// https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml
pub const ExtensionType = enum(u16) {
    /// RFC 6066
    server_name = 0,
    /// RFC 6066
    max_fragment_length = 1,
    /// RFC 6066
    status_request = 5,
    /// RFC 8422, 7919. renamed from "elliptic_curves"
    supported_groups = 10,
    /// RFC 8422 S5.1.2
    ec_point_formats = 11,
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
    /// RFC7366
    encrypt_then_mac = 22,
    /// RFC 7627
    extended_master_secret = 23,
    /// RFC 5077
    session_ticket = 35,
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
    /// Reserved for private use.
    none = 65280,
    _,
};

/// Matching error set for Alert.Description.
pub const Error = error{
    TlsUnexpectedMessage,
    TlsBadRecordMac,
    TlsRecordOverflow,
    TlsHandshakeFailure,
    TlsBadCertificate,
    TlsUnsupportedCertificate,
    TlsCertificateRevoked,
    TlsCertificateExpired,
    TlsCertificateUnknown,
    TlsIllegalParameter,
    TlsUnknownCa,
    TlsAccessDenied,
    TlsDecodeError,
    TlsDecryptError,
    TlsProtocolVersion,
    TlsInsufficientSecurity,
    TlsInternalError,
    TlsInappropriateFallback,
    TlsMissingExtension,
    TlsUnsupportedExtension,
    TlsUnrecognizedName,
    TlsBadCertificateStatusResponse,
    TlsUnknownPskIdentity,
    TlsCertificateRequired,
    TlsNoApplicationProtocol,
    TlsUnknown,
};

pub const Alert = struct {
    /// > In TLS 1.3, the severity is implicit in the type of alert being sent
    /// > and the "level" field can safely be ignored.
    level: Level,
    description: Description,

    pub const Level = enum(u8) {
        warning = 1,
        fatal = 2,
        _,
    };
    pub const Description = enum(u8) {
        /// Stream is closing.
        close_notify = 0,
        /// An inappropriate message (e.g., the wrong
        /// handshake message, premature Application Data, etc.) was received.
        /// This alert should never be observed in communication between
        /// proper implementations.
        unexpected_message = 10,
        /// This alert is returned if a record is received which
        /// cannot be deprotected.  Because AEAD algorithms combine decryption
        /// and verification, and also to avoid side-channel attacks, this
        /// alert is used for all deprotection failures.  This alert should
        /// never be observed in communication between proper implementations,
        /// except when messages were corrupted in the network.
        bad_record_mac = 20,
        /// A TLSCiphertext record was received that had a
        /// length more than 2^14 + 256 bytes, or a record decrypted to a
        /// TLSPlaintext record with more than 2^14 bytes (or some other
        /// negotiated limit).  This alert should never be observed in
        /// communication between proper implementations, except when messages
        /// were corrupted in the network.
        record_overflow = 22,
        /// Receipt of a "handshake_failure" alert message
        /// indicates that the sender was unable to negotiate an acceptable
        /// set of security parameters given the options available.
        handshake_failure = 40,
        /// A certificate was corrupt, contained signatures
        /// that did not verify correctly, etc.
        bad_certificate = 42,
        /// A certificate was of an unsupported type.
        unsupported_certificate = 43,
        /// A certificate was revoked by its signer.
        certificate_revoked = 44,
        /// A certificate has expired or is not currently valid.
        certificate_expired = 45,
        /// Some other (unspecified) issue arose in processing the certificate,
        /// rendering it unacceptable.
        certificate_unknown = 46,
        /// A field in the handshake was incorrect or
        /// inconsistent with other fields.  This alert is used for errors
        /// which conform to the formal protocol syntax but are otherwise
        /// incorrect.
        illegal_parameter = 47,
        /// A valid certificate chain or partial chain was received,
        /// but the certificate was not accepted because the CA certificate
        /// could not be located or could not be matched with a known trust
        /// anchor.
        unknown_ca = 48,
        /// A valid certificate or PSK was received, but when
        /// access control was applied, the sender decided not to proceed with
        /// negotiation.
        access_denied = 49,
        /// A message could not be decoded because some field was
        /// out of the specified range or the length of the message was
        /// incorrect.  This alert is used for errors where the message does
        /// not conform to the formal protocol syntax.  This alert should
        /// never be observed in communication between proper implementations,
        /// except when messages were corrupted in the network.
        decode_error = 50,
        /// A handshake (not record layer) cryptographic
        /// operation failed, including being unable to correctly verify a
        /// signature or validate a Finished message or a PSK binder.
        decrypt_error = 51,
        /// The protocol version the peer has attempted to
        /// negotiate is recognized but not supported (see Appendix D).
        protocol_version = 70,
        /// Returned instead of "handshake_failure" when
        /// a negotiation has failed specifically because the server requires
        /// parameters more secure than those supported by the client.
        insufficient_security = 71,
        /// An internal error unrelated to the peer or the
        /// correctness of the protocol (such as a memory allocation failure)
        /// makes it impossible to continue.
        internal_error = 80,
        /// Sent by a server in response to an invalid
        /// connection retry attempt from a client (see [RFC7507]).
        inappropriate_fallback = 86,
        /// User cancelled handshake.
        user_canceled = 90,
        /// Sent by endpoints that receive a handshake
        /// message not containing an extension that is mandatory to send for
        /// the offered TLS version or other negotiated parameters.
        missing_extension = 109,
        /// Sent by endpoints receiving any handshake
        /// message containing an extension known to be prohibited for
        /// inclusion in the given handshake message, or including any
        /// extensions in a ServerHello or Certificate not first offered in
        /// the corresponding ClientHello or CertificateRequest.
        unsupported_extension = 110,
        /// Sent by servers when no server exists identified
        /// by the name provided by the client via the "server_name" extension
        /// (see [RFC6066]).
        unrecognized_name = 112,
        /// Sent by clients when an invalid or
        /// unacceptable OCSP response is provided by the server via the
        /// "status_request" extension (see [RFC6066]).
        bad_certificate_status_response = 113,
        /// Sent by servers when PSK key establishment is
        /// desired but no acceptable PSK identity is provided by the client.
        /// Sending this alert is OPTIONAL; servers MAY instead choose to send
        /// a "decrypt_error" alert to merely indicate an invalid PSK
        /// identity.
        unknown_psk_identity = 115,
        /// Sent by servers when a client certificate is
        /// desired but none was provided by the client.
        certificate_required = 116,
        /// Sent by servers when a client
        /// "application_layer_protocol_negotiation" extension advertises only
        /// protocols that the server does not support (see [RFC7301]).
        no_application_protocol = 120,
        _,

        pub fn toError(alert: @This()) Error {
            return switch (alert) {
                .close_notify, .user_canceled => unreachable, // not an error
                .unexpected_message => Error.TlsUnexpectedMessage,
                .bad_record_mac => Error.TlsBadRecordMac,
                .record_overflow => Error.TlsRecordOverflow,
                .handshake_failure => Error.TlsHandshakeFailure,
                .bad_certificate => Error.TlsBadCertificate,
                .unsupported_certificate => Error.TlsUnsupportedCertificate,
                .certificate_revoked => Error.TlsCertificateRevoked,
                .certificate_expired => Error.TlsCertificateExpired,
                .certificate_unknown => Error.TlsCertificateUnknown,
                .illegal_parameter => Error.TlsIllegalParameter,
                .unknown_ca => Error.TlsUnknownCa,
                .access_denied => Error.TlsAccessDenied,
                .decode_error => Error.TlsDecodeError,
                .decrypt_error => Error.TlsDecryptError,
                .protocol_version => Error.TlsProtocolVersion,
                .insufficient_security => Error.TlsInsufficientSecurity,
                .internal_error => Error.TlsInternalError,
                .inappropriate_fallback => Error.TlsInappropriateFallback,
                .missing_extension => Error.TlsMissingExtension,
                .unsupported_extension => Error.TlsUnsupportedExtension,
                .unrecognized_name => Error.TlsUnrecognizedName,
                .bad_certificate_status_response => Error.TlsBadCertificateStatusResponse,
                .unknown_psk_identity => Error.TlsUnknownPskIdentity,
                .certificate_required => Error.TlsCertificateRequired,
                .no_application_protocol => Error.TlsNoApplicationProtocol,
                _ => Error.TlsUnknown,
            };
        }
    };

    const Self = @This();

    pub fn read(stream: *Stream) Self {
        const level = try stream.read(Level);
        const description = try stream.read(Description);
        return .{ .level = level, .description = description };
    }

    pub fn write(self: Self, stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.write(Level, self.level);
        res += try stream.write(Description, self.description);
        return res;
    }
};

/// Scheme for certificate verification
///
/// Note: This enum is named `SignatureScheme` because there is already a
/// `SignatureAlgorithm` type in TLS 1.2, which this replaces.
pub const SignatureScheme = enum(u16) {
    rsa_pkcs1_sha256 = 0x0401,
    rsa_pkcs1_sha384 = 0x0501,
    rsa_pkcs1_sha512 = 0x0601,

    ecdsa_secp256r1_sha256 = 0x0403,
    ecdsa_secp384r1_sha384 = 0x0503,
    ecdsa_secp521r1_sha512 = 0x0603,

    rsa_pss_rsae_sha256 = 0x0804,
    rsa_pss_rsae_sha384 = 0x0805,
    rsa_pss_rsae_sha512 = 0x0806,

    ed25519 = 0x0807,
    ed448 = 0x0808,

    rsa_pss_pss_sha256 = 0x0809,
    rsa_pss_pss_sha384 = 0x080a,
    rsa_pss_pss_sha512 = 0x080b,

    // Legacy algorithms
    rsa_pkcs1_sha1 = 0x0201,
    ecdsa_sha1 = 0x0203,

    _,

    pub fn Ecdsa(comptime self: @This()) type {
        return switch (self) {
            .ecdsa_secp256r1_sha256 => crypto.sign.ecdsa.EcdsaP256Sha256,
            .ecdsa_secp384r1_sha384 => crypto.sign.ecdsa.EcdsaP384Sha384,
            else => @compileError("bad scheme"),
        };
    }

    pub fn Hash(comptime self: @This()) type {
        return switch (self) {
            .ecdsa_secp256r1_sha256, .rsa_pss_rsae_sha256 => crypto.hash.sha2.Sha256,
            .ecdsa_secp384r1_sha384, .rsa_pss_rsae_sha384 => crypto.hash.sha2.Sha384,
            .ecdsa_secp521r1_sha512, .rsa_pss_rsae_sha512 => crypto.hash.sha2.Sha512,
            else => @compileError("bad scheme"),
        };
    }

    pub fn Eddsa(comptime self: @This()) type {
        return switch (self) {
            .ed25519 => crypto.sign.Ed25519,
            else => @compileError("bad scheme"),
        };
    }
};
pub const supported_signature_schemes = [_]SignatureScheme{
    .ecdsa_secp256r1_sha256,
    .ecdsa_secp384r1_sha384,
    .rsa_pss_rsae_sha256,
    .rsa_pss_rsae_sha384,
    .rsa_pss_rsae_sha512,
    .ed25519,
};

/// Key exchange formats
///
/// https://www.iana.org/assignments/tls-parameters/tls-parameters.xhtml
pub const NamedGroup = enum(u16) {
    // Use reserved value for invalid.
    invalid = 0x0000,
    // Elliptic Curve Groups (ECDHE)
    secp256r1 = 0x0017,
    secp384r1 = 0x0018,
    secp521r1 = 0x0019,
    x25519 = 0x001D,

    // Hybrid post-quantum key agreements. Still in draft.
    x25519_kyber768d00 = 0x6399,

    _,
};
pub fn NamedGroupT(comptime named_group: NamedGroup) type {
    return switch (named_group) {
        .secp256r1 => crypto.sign.ecdsa.EcdsaP256Sha256,
        .secp384r1 => crypto.sign.ecdsa.EcdsaP384Sha384,
        .x25519 => crypto.dh.X25519,
        else => |t| @compileError("unsupported named group " ++ @tagName(t)),
    };
}
pub const KeyPair = union(NamedGroup) {
    invalid: void,
    secp256r1: NamedGroupT(.secp256r1).KeyPair,
    secp384r1: NamedGroupT(.secp384r1).KeyPair,
    secp521r1: void,
    x25519: NamedGroupT(.x25519).KeyPair,
    x25519_kyber768d00: void,

    pub fn toKeyShare(self: @This()) KeyShare {
        return switch (self) {
            .secp256r1 => |k| .{ .secp256r1 = k.public_key },
            .secp384r1 => |k| .{ .secp384r1 = k.public_key },
            .x25519 => |k| .{ .x25519 = k.public_key },
            inline else => |_, t| @unionInit(KeyShare, @tagName(t), {}),
        };
    }
};
/// The public portion of a KeyPair.
pub const KeyShare = union(NamedGroup) {
    invalid: void,
    secp256r1: NamedGroupT(.secp256r1).PublicKey,
    secp384r1: NamedGroupT(.secp384r1).PublicKey,
    secp521r1: void,
    x25519: NamedGroupT(.x25519).PublicKey,
    x25519_kyber768d00: void,

    const Self = @This();

    pub fn read(stream: *Stream) !Self {
        std.debug.assert(!stream.is_client);

        var reader = stream.any().reader();
        const group = try stream.read(NamedGroup);
        const len = try stream.read(u16);
        switch (group) {
            inline .secp256r1, .secp384r1 => |k| {
                const T = NamedGroupT(k).PublicKey;
                var buf: [T.uncompressed_sec1_encoded_length]u8 = undefined;
                try reader.readNoEof(&buf);
                const val = T.fromSec1(&buf) catch return Error.TlsDecryptError;
                return @unionInit(Self, @tagName(k), val);
            },
            .x25519 => {
                var res = Self{ .x25519 = undefined };
                try reader.readNoEof(&res.x25519);
                return res;
            },
            else => {
                try reader.skipBytes(len, .{});
            },
        }
        return .{ .invalid = {} };
    }

    pub fn write(self: Self, stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.write(NamedGroup, self);
        const public = switch (self) {
            .secp256r1 => |k| &k.toUncompressedSec1(),
            .secp384r1 => |k| &k.toUncompressedSec1(),
            .x25519 => |k| &k,
            else => "",
        };
        res += try stream.writeArray(u16, u8, public);
        return res;
    }
};
/// In descending order of preference
pub const supported_groups = [_]NamedGroup{
    .secp256r1,
    .secp384r1,
    .x25519,
};

pub const CipherSuite = enum(u16) {
    aes_128_gcm_sha256 = 0x1301,
    aes_256_gcm_sha384 = 0x1302,
    chacha20_poly1305_sha256 = 0x1303,
    aegis_256_sha512 = 0x1306,
    aegis_128l_sha256 = 0x1307,
    _,

    pub fn Hash(comptime self: @This()) type {
        return switch (self) {
            .aes_128_gcm_sha256 => crypto.hash.sha2.Sha256,
            .aes_256_gcm_sha384 => crypto.hash.sha2.Sha384,
            .chacha20_poly1305_sha256 => crypto.hash.sha2.Sha256,
            .aegis_256_sha512 => crypto.hash.sha2.Sha512,
            .aegis_128l_sha256 => crypto.hash.sha2.Sha256,
            else => @compileError("unknown suite " ++ @tagName(self)),
        };
    }

    pub fn Aead(comptime self: @This()) type {
        return switch (self) {
            .aes_128_gcm_sha256 => crypto.aead.aes_gcm.Aes128Gcm,
            .aes_256_gcm_sha384 => crypto.aead.aes_gcm.Aes256Gcm,
            .chacha20_poly1305_sha256 => crypto.aead.chacha_poly.ChaCha20Poly1305,
            .aegis_256_sha512 => crypto.aead.aegis.Aegis256,
            .aegis_128l_sha256 => crypto.aead.aegis.Aegis128L,
            else => @compileError("unknown suite " ++ @tagName(self)),
        };
    }
};

pub const HandshakeCipher = union(CipherSuite) {
    aes_128_gcm_sha256: HandshakeCipherT(.aes_128_gcm_sha256),
    aes_256_gcm_sha384: HandshakeCipherT(.aes_256_gcm_sha384),
    chacha20_poly1305_sha256: HandshakeCipherT(.chacha20_poly1305_sha256),
    aegis_256_sha512: HandshakeCipherT(.aegis_256_sha512),
    aegis_128l_sha256: HandshakeCipherT(.aegis_128l_sha256),

    const Self = @This();

    pub fn init(suite: CipherSuite, shared_key: []const u8, hello_hash: []const u8) Error!Self {
        switch (suite) {
            inline .aes_128_gcm_sha256,
            .aes_256_gcm_sha384,
            .chacha20_poly1305_sha256,
            .aegis_256_sha512,
            .aegis_128l_sha256,
            => |tag| {
                var res = @unionInit(Self, @tagName(tag), .{
                    .handshake_secret = undefined,
                    .master_secret = undefined,
                    .client_finished_key = undefined,
                    .server_finished_key = undefined,
                    .client_key = undefined,
                    .server_key = undefined,
                    .client_iv = undefined,
                    .server_iv = undefined,
                });
                const P = std.meta.TagPayloadByName(Self, @tagName(tag));
                const p = &@field(res, @tagName(tag));

                const zeroes = [1]u8{0} ** P.Hash.digest_length;
                const early_secret = P.Hkdf.extract(&[1]u8{0}, &zeroes);
                const empty_hash = emptyHash(P.Hash);

                const derived_secret = hkdfExpandLabel(P.Hkdf, early_secret, "derived", &empty_hash, P.Hash.digest_length);
                p.handshake_secret = P.Hkdf.extract(&derived_secret, shared_key);
                const ap_derived_secret = hkdfExpandLabel(P.Hkdf, p.handshake_secret, "derived", &empty_hash, P.Hash.digest_length);
                p.master_secret = P.Hkdf.extract(&ap_derived_secret, &zeroes);
                const client_secret = hkdfExpandLabel(P.Hkdf, p.handshake_secret, "c hs traffic", hello_hash, P.Hash.digest_length);
                const server_secret = hkdfExpandLabel(P.Hkdf, p.handshake_secret, "s hs traffic", hello_hash, P.Hash.digest_length);
                p.client_finished_key = hkdfExpandLabel(P.Hkdf, client_secret, "finished", "", P.Hmac.key_length);
                p.server_finished_key = hkdfExpandLabel(P.Hkdf, server_secret, "finished", "", P.Hmac.key_length);
                p.client_key = hkdfExpandLabel(P.Hkdf, client_secret, "key", "", P.AEAD.key_length);
                p.server_key = hkdfExpandLabel(P.Hkdf, server_secret, "key", "", P.AEAD.key_length);
                p.client_iv = hkdfExpandLabel(P.Hkdf, client_secret, "iv", "", P.AEAD.nonce_length);
                p.server_iv = hkdfExpandLabel(P.Hkdf, server_secret, "iv", "", P.AEAD.nonce_length);

                return res;
            },
            _ => return Error.TlsIllegalParameter,
        }
    }

    pub fn print(self: Self) void {
        switch (self) {
            inline else => |v| v.print(),
        }
    }
};

pub const ApplicationCipher = union(CipherSuite) {
    aes_128_gcm_sha256: ApplicationCipherT(.aes_128_gcm_sha256),
    aes_256_gcm_sha384: ApplicationCipherT(.aes_256_gcm_sha384),
    chacha20_poly1305_sha256: ApplicationCipherT(.chacha20_poly1305_sha256),
    aegis_256_sha512: ApplicationCipherT(.aegis_256_sha512),
    aegis_128l_sha256: ApplicationCipherT(.aegis_128l_sha256),

    const Self = @This();

    pub fn init(handshake_cipher: HandshakeCipher, handshake_hash: []const u8) Self {
        switch (handshake_cipher) {
            inline .aes_128_gcm_sha256,
            .aes_256_gcm_sha384,
            .chacha20_poly1305_sha256,
            .aegis_256_sha512,
            .aegis_128l_sha256,
            => |c, tag| {
                var res = @unionInit(Self, @tagName(tag), .{
                    .client_secret = undefined,
                    .server_secret = undefined,
                    .client_key = undefined,
                    .server_key = undefined,
                    .client_iv = undefined,
                    .server_iv = undefined,
                });
                const P = std.meta.TagPayloadByName(Self, @tagName(tag));
                const p = &@field(res, @tagName(tag));

                const zeroes = [1]u8{0} ** P.Hash.digest_length;
                const empty_hash = emptyHash(P.Hash);

                const derived_secret = hkdfExpandLabel(P.Hkdf, c.handshake_secret, "derived", &empty_hash, P.Hash.digest_length);
                const master_secret = P.Hkdf.extract(&derived_secret, &zeroes);
                p.client_secret = hkdfExpandLabel(P.Hkdf, master_secret, "c ap traffic", handshake_hash, P.Hash.digest_length);
                p.server_secret = hkdfExpandLabel(P.Hkdf, master_secret, "s ap traffic", handshake_hash, P.Hash.digest_length);
                p.client_key = hkdfExpandLabel(P.Hkdf, p.client_secret, "key", "", P.AEAD.key_length);
                p.server_key = hkdfExpandLabel(P.Hkdf, p.server_secret, "key", "", P.AEAD.key_length);
                p.client_iv = hkdfExpandLabel(P.Hkdf, p.client_secret, "iv", "", P.AEAD.nonce_length);
                p.server_iv = hkdfExpandLabel(P.Hkdf, p.server_secret, "iv", "", P.AEAD.nonce_length);

                return res;
            },
        }
    }

    pub fn print(self: Self) void {
        switch (self) {
            inline else => |v| v.print(),
        }
    }
};

/// RFC 8446 S4.1.2
pub const ClientHello = struct {
    /// Legacy field for TLS 1.2 middleboxes
    version: Version = .tls_1_2,
    random: [32]u8,
    /// Legacy session resumption. Max len 32.
    session_id: []const u8,
    /// In descending order of preference
    cipher_suites: []const CipherSuite,
    // Legacy and unsecure, requires at least 1 for compat, MUST error if anything else
    compression_methods: [1]u8 = .{0},
    // Certain extensions are mandatory for TLS 1.3
    extensions: []const Extension,

    pub const session_id_max_len = 32;

    const Self = @This();

    pub fn write(self: Self, stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.write(Version, self.version);
        res += try stream.writeAll(&self.random);
        res += try stream.writeArray(u8, u8, self.session_id);
        res += try stream.writeArray(u16, CipherSuite, self.cipher_suites);
        res += try stream.writeArray(u8, u8, &self.compression_methods);
        res += try stream.writeArray(u16, Extension, self.extensions);
        return res;
    }
};

pub const ServerHello = struct {
    /// Legacy field for TLS 1.2 middleboxes
    version: Version = .tls_1_2,
    /// Should be an echo of the sent `client_random`.
    random: [32]u8,
    /// Legacy session resumption
    session_id: []const u8,
    cipher_suite: CipherSuite,
    compression_method: u8 = 0,
    /// Certain extensions are mandatory for TLS 1.3
    extensions: []const Extension,

    /// When `random` equals this it means the client should resend the `ClientHello`.
    pub const hello_retry_request = [32]u8{
        0xCF, 0x21, 0xAD, 0x74, 0xE5, 0x9A, 0x61, 0x11, 0xBE, 0x1D, 0x8C, 0x02, 0x1E, 0x65, 0xB8, 0x91,
        0xC2, 0xA2, 0x11, 0x16, 0x7A, 0xBB, 0x8C, 0x5E, 0x07, 0x9E, 0x09, 0xE2, 0xC8, 0xA8, 0x33, 0x9C,
    };

    const Self = @This();

    pub fn write(self: Self, stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.write(Version, self.version);
        res += try stream.writeAll(&self.random);
        res += try stream.writeArray(u8, u8, self.session_id);
        res += try stream.write(CipherSuite, self.cipher_suite);
        res += try stream.write(u8, self.compression_method);
        res += try stream.writeArray(u16, Extension, self.extensions);
        return res;
    }
};

pub const EncryptedExtensions = struct {
    extensions: []const Extension,

    const Self = @This();

    pub fn write(self: Self, stream: *Stream) !usize {
        return try stream.writeArray(u16, Extension, self.extensions);
    }
};

pub const Extension = union(ExtensionType) {
    // MUST NOT contain more than one name of the same name_type
    server_name: []const ServerName,
    max_fragment_length: void,
    status_request: void,
    supported_groups: []const NamedGroup,
    ec_point_formats: []const EcPointFormat,
    /// For signature_verify messages
    signature_algorithms: []const SignatureScheme,
    use_srtp: void,
    /// https://en.wikipedia.org/wiki/Heartbleed
    heartbeat: void,
    application_layer_protocol_negotiation: void,
    signed_certificate_timestamp: void,
    client_certificate_type: void,
    server_certificate_type: void,
    padding: void,
    encrypt_then_mac: void,
    extended_master_secret: void,
    session_ticket: void,
    pre_shared_key: void,
    early_data: void,
    supported_versions: []const Version,
    cookie: void,
    psk_key_exchange_modes: []const PskKeyExchangeMode,
    certificate_authorities: void,
    oid_filters: void,
    post_handshake_auth: void,
    /// For certificate signatures.
    /// > Implementations which have the same policy in both cases MAY omit the
    /// > "signature_algorithms_cert" extension.
    signature_algorithms_cert: void,
    key_share: []const KeyShare,
    none: void,

    const Self = @This();

    pub fn write(self: Self, stream: *Stream) !usize {
        const PrefixLen = enum { zero, one, two };
        const prefix_len: PrefixLen = if (stream.is_client) switch (self) {
            .supported_versions, .ec_point_formats, .psk_key_exchange_modes => .one,
            .server_name, .supported_groups, .signature_algorithms, .key_share => .two,
            else => .zero,
        } else .zero;

        var res: usize = 0;
        res += try stream.write(ExtensionType, self);

        switch (self) {
            inline else => |items| {
                const T = @TypeOf(items);
                switch (@typeInfo(T)) {
                    .Void => {
                        res += try stream.write(u16, 0);
                    },
                    .Pointer => |info| {
                        switch (prefix_len) {
                            inline else => |t| {
                                const PrefixT = switch (t) {
                                    .zero => void,
                                    .one => u8,
                                    .two => u16,
                                };
                                const len = stream.arrayLength(PrefixT, info.child, items);
                                res += try stream.write(u16, @intCast(len));
                                res += try stream.writeArray(PrefixT, info.child, items);
                            },
                        }
                    },
                    else => |t| @compileError("unsupported type " ++ @typeName(T) ++ " for member " ++ @tagName(t)),
                }
            },
        }
        return res;
    }

    pub const Header = struct {
        type: ExtensionType,
        len: u16,

        pub fn read(stream: *Stream) @TypeOf(stream.*).ReadError!@This() {
            const ty = try stream.read(ExtensionType);
            const length = try stream.read(u16);
            return .{ .type = ty, .len = length };
        }
    };
};

/// RFC 8446 S4.2.9
pub const PskKeyExchangeMode = enum(u8) {
    /// PSK-only key establishment.  In this mode, the server
    /// MUST NOT supply a "key_share" value.
    ke = 1,
    /// PSK with (EC)DHE key establishment.  In this mode, the
    /// client and server MUST supply "key_share" values as described in
    /// Section 4.2.8.
    dhe_ke = 2,
    _,
};

/// RFC 8446 S4.1.3
pub const ServerName = struct {
    type: NameType = .host_name,
    host_name: []const u8,

    pub const NameType = enum(u8) { host_name = 0, _ };

    pub fn write(self: @This(), stream: *Stream) !usize {
        var res: usize = 0;
        res += try stream.write(NameType, self.type);
        res += try stream.writeArray(u16, u8, self.host_name);
        return res;
    }
};

pub const EcPointFormat = enum(u8) {
    uncompressed = 0,
    ansiX962_compressed_prime = 1,
    ansiX962_compressed_char2 = 2,
    _,
};

/// RFC 5246 S7.1
pub const ChangeCipherSpec = enum(u8) { change_cipher_spec = 1, _ };

/// One of these potential hashes will be selected after receiving the other party's hello.
///
/// We init them before sending any messages to avoid having to store our first message until the
/// other party's handshake message returns. This message is usually larger than
/// `@sizeOf(MultiHash)` = 560
///
/// A nice benefit is decreased latency on hosts where one round trip takes longer than calling
/// `update` with `active == .all`.
pub const MultiHash = struct {
    sha256: sha2.Sha256 = sha2.Sha256.init(.{}),
    sha384: sha2.Sha384 = sha2.Sha384.init(.{}),
    sha512: sha2.Sha512 = sha2.Sha512.init(.{}),
    /// Chosen during handshake.
    active: enum { all, sha256, sha384, sha512, none } = .all,

    const sha2 = crypto.hash.sha2;
    pub const max_digest_len = sha2.Sha512.digest_length;
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
            .none => {},
        }
    }

    pub fn setActive(self: *Self, cipher_suite: CipherSuite) void {
        self.active = switch (cipher_suite) {
            .aes_128_gcm_sha256, .chacha20_poly1305_sha256, .aegis_128l_sha256 => .sha256,
            .aes_256_gcm_sha384 => .sha384,
            .aegis_256_sha512 => .sha512,
            _ => .all,
        };
    }

    pub inline fn peek(self: Self) []const u8 {
        return &switch (self.active) {
            .all, .none => [_]u8{},
            .sha256 => self.sha256.peek(),
            .sha384 => self.sha384.peek(),
            .sha512 => self.sha512.peek(),
        };
    }
};

fn HandshakeCipherT(comptime suite: CipherSuite) type {
    return struct {
        pub const AEAD = suite.Aead();
        pub const Hash = suite.Hash();
        pub const Hmac = crypto.auth.hmac.Hmac(Hash);
        pub const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        handshake_secret: [Hkdf.prk_length]u8,
        master_secret: [Hkdf.prk_length]u8,
        client_finished_key: [Hmac.key_length]u8,
        server_finished_key: [Hmac.key_length]u8,
        client_key: [AEAD.key_length]u8,
        server_key: [AEAD.key_length]u8,
        client_iv: [AEAD.nonce_length]u8,
        server_iv: [AEAD.nonce_length]u8,
        read_seq: usize = 0,
        write_seq: usize = 0,

        const Self = @This();

        pub fn encrypt(
            self: *Self,
            data: []const u8,
            additional: []const u8,
            is_client: bool,
            out: []u8,
        ) [AEAD.tag_length]u8 {
            var res: [AEAD.tag_length]u8 = undefined;
            const key = if (is_client) self.client_key else self.server_key;
            const iv = if (is_client) self.client_iv else self.server_iv;
            const nonce = nonce_for_len(AEAD.nonce_length, iv, self.write_seq);
            AEAD.encrypt(out, &res, data, additional, nonce, key);
            self.write_seq += 1;
            return res;
        }

        pub fn decrypt(
            self: *Self,
            data: []const u8,
            additional: []const u8,
            tag: [AEAD.tag_length]u8,
            is_client: bool,
            out: []u8,
        ) Error!void {
            const key = if (is_client) self.server_key else self.client_key;
            const iv = if (is_client) self.server_iv else self.client_iv;
            const nonce = nonce_for_len(AEAD.nonce_length, iv, self.read_seq);
            AEAD.decrypt(out, data, tag, additional, nonce, key) catch return Error.TlsBadRecordMac;
            self.read_seq += 1;
        }

        pub fn print(self: Self) void {
            inline for (std.meta.fields(Self)) |f| debugPrint(f.name, @field(self, f.name));
        }
    };
}

fn ApplicationCipherT(comptime suite: CipherSuite) type {
    return struct {
        pub const AEAD = suite.Aead();
        pub const Hash = suite.Hash();
        pub const Hmac = crypto.auth.hmac.Hmac(Hash);
        pub const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);

        client_secret: [Hash.digest_length]u8,
        server_secret: [Hash.digest_length]u8,
        client_key: [AEAD.key_length]u8,
        server_key: [AEAD.key_length]u8,
        client_iv: [AEAD.nonce_length]u8,
        server_iv: [AEAD.nonce_length]u8,
        read_seq: usize = 0,
        write_seq: usize = 0,

        const Self = @This();

        pub fn encrypt(
            self: *Self,
            data: []const u8,
            additional: []const u8,
            is_client: bool,
            out: []u8,
        ) [AEAD.tag_length]u8 {
            var res: [AEAD.tag_length]u8 = undefined;
            const key = if (is_client) self.client_key else self.server_key;
            const iv = if (is_client) self.client_iv else self.server_iv;
            const nonce = nonce_for_len(AEAD.nonce_length, iv, self.write_seq);
            AEAD.encrypt(out, &res, data, additional, nonce, key);
            self.write_seq += 1;
            return res;
        }

        pub fn decrypt(
            self: *Self,
            data: []const u8,
            additional: []const u8,
            tag: [AEAD.tag_length]u8,
            is_client: bool,
            out: []u8,
        ) !void {
            const key = if (is_client) self.server_key else self.client_key;
            const iv = if (is_client) self.server_iv else self.client_iv;
            const nonce = nonce_for_len(AEAD.nonce_length, iv, self.read_seq);
            try AEAD.decrypt(out, data, tag, additional, nonce, key);
            self.read_seq += 1;
        }

        pub fn print(self: Self) void {
            inline for (std.meta.fields(Self)) |f| debugPrint(f.name, @field(self, f.name));
        }
    };
}

fn nonce_for_len(len: comptime_int, iv: [len]u8, seq: usize) [len]u8 {
    if (builtin.zig_backend == .stage2_x86_64 and len > comptime std.simd.suggestVectorLength(u8) orelse 1) {
        var res = iv;
        const operand = std.mem.readInt(u64, res[res.len - 8 ..], .big);
        std.mem.writeInt(u64, res[res.len - 8 ..], operand ^ seq, .big);
        return res;
    } else {
        const V = @Vector(len, u8);
        const pad = [1]u8{0} ** (len - 8);
        const big = switch (native_endian) {
            .big => seq,
            .little => @byteSwap(seq),
        };
        const operand: V = pad ++ @as([8]u8, @bitCast(big));
        return @as(V, iv) ^ operand;
    }
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

/// Slice of stack allocated signature content from RFC 8446 S4.4.3
pub inline fn sigContent(digest: []const u8) []const u8 {
    const max_digest_len = MultiHash.max_digest_len;
    var buf = [_]u8{0x20} ** 64 ++ "TLS 1.3, server CertificateVerify\x00".* ++ @as([max_digest_len]u8, undefined);
    @memcpy(buf[buf.len - max_digest_len ..][0..digest.len], digest);

    return buf[0 .. buf.len - (max_digest_len - digest.len)];
}

/// Default suites used for client and server in descending order of preference.
/// The order is chosen based on what crypto algorithms Zig has available in
/// the standard library and their speed on x86_64-linux.
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
pub const default_cipher_suites =
    if (crypto.core.aes.has_hardware_support)
    [_]CipherSuite{
        .aegis_128l_sha256,
        .aegis_256_sha512,
        .aes_128_gcm_sha256,
        .aes_256_gcm_sha384,
        .chacha20_poly1305_sha256,
    }
else
    [_]CipherSuite{
        .chacha20_poly1305_sha256,
        .aegis_128l_sha256,
        .aegis_256_sha512,
        .aes_128_gcm_sha256,
        .aes_256_gcm_sha384,
    };

// Implements `StreamInterface` with a ring buffer
const TestStream = struct {
    buffer: Buffer,

    const Buffer = std.RingBuffer;
    const Self = @This();

    pub const ReadError = Buffer.Error;
    pub const WriteError = Buffer.Error;

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{ .buffer = try Buffer.init(allocator, Plaintext.max_length) };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.buffer.deinit(allocator);
    }

    pub fn readv(self: *Self, iov: []const std.os.iovec) ReadError!usize {
        const first = iov[0];
        try self.buffer.readFirst(first.iov_base[0..first.iov_len], first.iov_len);
        return first.iov_len;
    }

    pub fn writev(self: *Self, iov: []const std.os.iovec_const) WriteError!usize {
        var written: usize = 0;
        for (iov) |v| {
            try self.buffer.writeSlice(v.iov_base[0..v.iov_len]);
            written += v.iov_len;
        }
        return written;
    }

    pub fn peek(self: *Self, out: []u8) ReadError!void {
        const read_index = self.buffer.read_index;
        _ = try self.read(out);
        self.buffer.read_index = read_index;
    }

    pub fn close(self: *Self) void {
        _ = self;
    }

    pub fn expect(self: *Self, expected: []const u8) !void {
        var tmp_buf: [Plaintext.max_length]u8 = undefined;
        const buf = tmp_buf[0..self.buffer.len()];
        try self.peek(buf);

        try std.testing.expectEqualSlices(u8, expected, buf);
    }

    const GenericStream = std.io.GenericStream(*Self, ReadError, readv, WriteError, writev, close);

    pub fn stream(self: *Self) GenericStream {
        return .{ .context = self };
    }
};

test "tls client and server handshake, data, and close_notify" {
    const allocator = std.testing.allocator;

    var inner_stream = try TestStream.init(allocator);
    defer inner_stream.deinit(allocator);
    const stream = inner_stream.stream();

    var client_transcript: MultiHash = .{};
    var client = Client{
        .stream = Stream{
            .stream = stream.any(),
            .is_client = true,
            .transcript_hash = &client_transcript,
        },
        .options = .{ .host = "localhost", .ca_bundle = null, .allocator = allocator },
    };

    const server_cert = @embedFile("./testdata/cert.der");
    const server_key = @embedFile("./testdata/key.der");
    const server_rsa = try crypto.Certificate.rsa.SecretKey.fromDer(server_key);
    var server_transcript: MultiHash = .{};
    var server = Server{
        .stream = Stream{
            .stream = stream.any(),
            .is_client = false,
            .transcript_hash = &server_transcript,
        },
        .options = .{
            .cipher_suites = &[_]CipherSuite{.aes_256_gcm_sha384},
            .key_shares = &[_]NamedGroup{.x25519},
            .certificate = .{ .entries = &[_]Certificate.Entry{
                .{ .data = server_cert },
            } },
            .certificate_key = .{ .rsa = server_rsa },
        },
    };

    // Use these seeded values for reproducible handshake and application ciphertext.
    const session_id: [32]u8 = ("session_id012345" ** 2).*;
    const client_random: [32]u8 = ("client_random012" ** 2).*;
    const server_random: [32]u8 = ("server_random012" ** 2).*;
    const client_key_seed: [32]u8 = ("client_seed01234" ** 2).*;
    const server_keygen_seed: [48]u8 = ("server_seed01234" ** 3).*;
    const server_sig_salt: [MultiHash.max_digest_len]u8 = ("server_sig_salt0" ** 4).*;

    const key_pairs = try Client.KeyPairs.initAdvanced(
        client_random,
        session_id,
        client_key_seed,
        client_key_seed ++ [_]u8{0} ** (48 - 32),
        client_key_seed,
    );
    var client_command = Client.Command{ .send_hello = key_pairs };
    client_command = try client.next(client_command);
    try std.testing.expect(client_command == .recv_hello);

    var server_command = Server.Command{ .recv_hello = .{
        .server_random = server_random,
        .keygen_seed = server_keygen_seed,
    } };
    server_command = try server.next(server_command); // recv_hello
    try std.testing.expect(server_command == .send_hello);

    server_command = try server.next(server_command); // send_hello
    try std.testing.expect(server_command == .send_change_cipher_spec);

    client_command = try client.next(client_command); // recv_hello
    try std.testing.expect(client_command == .recv_encrypted_extensions);
    {
        const s = server.stream.cipher.handshake.aes_256_gcm_sha384;
        const c = client.stream.cipher.handshake.aes_256_gcm_sha384;

        try std.testing.expectEqualSlices(u8, &s.handshake_secret, &c.handshake_secret);
        try std.testing.expectEqualSlices(u8, &s.master_secret, &c.master_secret);
        try std.testing.expectEqualSlices(u8, &s.server_finished_key, &c.server_finished_key);
        try std.testing.expectEqualSlices(u8, &s.client_finished_key, &c.client_finished_key);
        try std.testing.expectEqualSlices(u8, &s.server_key, &c.server_key);
        try std.testing.expectEqualSlices(u8, &s.client_key, &c.client_key);
        try std.testing.expectEqualSlices(u8, &s.server_iv, &c.server_iv);
        try std.testing.expectEqualSlices(u8, &s.client_iv, &c.client_iv);
    }

    server_command = try server.next(server_command); // send_change_cipher_spec
    try std.testing.expect(server_command == .send_encrypted_extensions);
    server_command = try server.next(server_command); // send_encrypted_extensions
    try std.testing.expect(server_command == .send_certificate);
    server_command = try server.next(server_command); // send_certificate
    try std.testing.expect(server_command == .send_certificate_verify);
    server_command.send_certificate_verify.salt = server_sig_salt;
    server_command = try server.next(server_command); // send_certificate_verify
    try std.testing.expect(server_command == .send_finished);
    server_command = try server.next(server_command); // send_finished
    try std.testing.expect(server_command == .recv_finished);

    client_command = try client.next(client_command); // recv_encrypted_extensions
    try std.testing.expect(client_command == .recv_certificate_or_finished);
    client_command = try client.next(client_command); // recv_certificate_or_finished (certificate)
    try std.testing.expect(client_command == .recv_certificate_verify);
    client_command = try client.next(client_command); // recv_certificate_verify
    try std.testing.expect(client_command == .recv_finished);
    client_command = try client.next(client_command); // recv_finished
    try std.testing.expect(client_command == .send_change_cipher_spec);
    client_command = try client.next(client_command); // send_change_cipher_spec
    try std.testing.expect(client_command == .send_finished);
    client_command = try client.next(client_command); // send_finished
    try std.testing.expect(client_command == .none);

    server_command = try server.next(server_command); // recv_finished
    try std.testing.expect(server_command == .none);
    {
        const s = server.stream.cipher.application.aes_256_gcm_sha384;
        const c = client.stream.cipher.application.aes_256_gcm_sha384;

        try std.testing.expectEqualSlices(u8, &s.client_secret, &c.client_secret);
        try std.testing.expectEqualSlices(u8, &s.server_secret, &c.server_secret);
        try std.testing.expectEqualSlices(u8, &s.client_key, &c.client_key);
        try std.testing.expectEqualSlices(u8, &s.server_key, &c.server_key);
        try std.testing.expectEqualSlices(u8, &s.client_iv, &c.client_iv);
        try std.testing.expectEqualSlices(u8, &s.server_iv, &c.server_iv);
    }

    try client.any().writer().writeAll("ping");

    var recv_ping: [4]u8 = undefined;
    _ = try server.stream.any().reader().readAll(&recv_ping);
    try std.testing.expectEqualStrings("ping", &recv_ping);

    server.stream.close();
    try std.testing.expect(server.stream.closed);

    _ = try client.stream.readPlaintext();
    try std.testing.expect(client.stream.closed);
}

pub fn debugPrint(name: []const u8, slice: anytype) void {
    std.debug.print("{s} ", .{name});
    if (@typeInfo(@TypeOf(slice)) == .Int) {
        std.debug.print("{d} ", .{slice});
    } else {
        for (slice) |c| std.debug.print("{x:0>2} ", .{c});
    }
    std.debug.print("\n", .{});
}

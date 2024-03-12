const std = @import("../std.zig");
const builtin = @import("builtin");
const client_mod = @import("tls/Client.zig");
const server_mod = @import("tls/Server.zig");
const Tls = @This();
const net = std.net;
const mem = std.mem;
const crypto = std.crypto;
const assert = std.debug.assert;
const native_endian = builtin.cpu.arch.endian();

pub const Client = client_mod.Client;
pub const Server = server_mod.Server;

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

/// Also called a Record.
pub const Plaintext = struct {
    type: ContentType,
    version: Version = .tls_1_0,
    /// > The length MUST NOT exceed 2^14 bytes.
    /// > An endpoint that receives a record that exceeds this length MUST terminate the connection
    /// > with a "record_overflow" alert.
    length: u16,
    // `length` bytes follow which may contain a Message or a partial Message.

    pub const max_length = 1 << 14;
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
    key_update: void,
    message_hash: void,

    // If `HandshakeCipherT.encode` accepts iovecs for the message this can be moved
    // to `Stream.writeFragment` and this type can be deleted.
    pub fn write(self: @This(), stream: anytype) !usize {
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
                    else => |t| @compileError("implement writing " ++ @tagName(t)),
                }
            }
        }
        return res;
    }

    pub const Header = struct {
        type: HandshakeType,
        len: u24,
    };
};

pub const Certificate = struct {
    context: []const u8 = "",
    entries: []const Entry,

    pub const max_context_len = 255;

    pub const Entry = struct {
        /// Either ASN1_subjectPublicKeyInfo or cert_data based on CertificateType.
        data: []const u8,
        extensions: []const Extension = &.{},

        pub const max_data_len = 1 << 24 - 1;

        pub fn write(self: @This(), stream: anytype) !usize {
            var res: usize = 0;
            res += try stream.writeArray(u24, u8, self.data);
            res += try stream.writeArray(u16, Extension, self.extensions);
            return res;
        }
    };

    const Self = @This();

    pub fn write(self: Self, stream: anytype) !usize {
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

    pub fn write(self: @This(), stream: anytype) !usize {
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

    pub fn read(stream: anytype) Self {
        const level = try stream.read(Level);
        const description = try stream.read(Description);
        return .{ .level = level, .description = description };
    }

    pub fn write(self: Self, stream: anytype) !usize {
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

    fn Ecdsa(comptime self: @This()) type {
        return switch (self) {
            .ecdsa_secp256r1_sha256 => crypto.sign.ecdsa.EcdsaP256Sha256,
            .ecdsa_secp384r1_sha384 => crypto.sign.ecdsa.EcdsaP384Sha384,
            else => @compileError("bad scheme"),
        };
    }

    fn Hash(comptime self: @This()) type {
        return switch (self) {
            .rsa_pss_rsae_sha256 => crypto.hash.sha2.Sha256,
            .rsa_pss_rsae_sha384 => crypto.hash.sha2.Sha384,
            .rsa_pss_rsae_sha512 => crypto.hash.sha2.Sha512,
            else => @compileError("bad scheme"),
        };
    }

    fn Eddsa(comptime self: @This()) type {
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
pub const NamedGroup = enum(u16) {
    invalid = 0x0000,
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

    // Hybrid post-quantum key agreements. Still in draft.
    x25519_kyber768d00 = 0x6399,

    _,
};
pub fn NamedGroupT(comptime named_group: NamedGroup) type {
    return switch (named_group) {
        .secp256r1 => crypto.sign.ecdsa.EcdsaP256Sha256,
        .secp384r1 => crypto.sign.ecdsa.EcdsaP384Sha384,
        .x25519 => crypto.dh.X25519,
        .x25519_kyber768d00 => X25519Kyber768Draft,
        else => |t| @compileError("unsupported named group " ++ @tagName(t)),
    };
}
// Hybrid share, see https://www.ietf.org/archive/id/draft-ietf-tls-hybrid-design-05.html
pub const X25519Kyber768Draft = struct {
    pub const X25519 = NamedGroupT(.x25519);
    pub const Kyber768 = crypto.kem.kyber_d00.Kyber768;
    pub const KeyPair = struct {
        x25519: X25519.KeyPair,
        kyber768d00: Kyber768.KeyPair,
    };
    pub const PublicKey = struct {
        x25519: X25519.PublicKey,
        kyber768d00: Kyber768.PublicKey,

        pub const bytes_length = X25519.public_length + Kyber768.PublicKey.bytes_length;

        pub fn toBytes(self: @This()) [bytes_length]u8 {
            return self.x25519 ++ self.kyber768d00.toBytes();
        }

        pub fn ciphertext(self: @This()) [X25519.public_length + Kyber768.ciphertext_length]u8 {
            return self.x25519 ++ self.kyber768d00.encaps(null).ciphertext;
        }
    };
};
pub const KeyPair = union(NamedGroup) {
    invalid: void,
    secp256r1: NamedGroupT(.secp256r1).KeyPair,
    secp384r1: NamedGroupT(.secp384r1).KeyPair,
    secp521r1: void,
    x25519: NamedGroupT(.x25519).KeyPair,
    x448: void,

    ffdhe2048: void,
    ffdhe3072: void,
    ffdhe4096: void,
    ffdhe6144: void,
    ffdhe8192: void,

    x25519_kyber768d00: NamedGroupT(.x25519_kyber768d00).KeyPair,

    pub fn toKeyShare(self: @This()) KeyShare {
        return switch (self) {
            .x25519_kyber768d00 => |k| .{ .x25519_kyber768d00 = X25519Kyber768Draft.PublicKey{
                .x25519 = k.x25519.public_key,
                .kyber768d00 = k.kyber768d00.public_key,
            } },
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
    x448: void,

    ffdhe2048: void,
    ffdhe3072: void,
    ffdhe4096: void,
    ffdhe6144: void,
    ffdhe8192: void,

    x25519_kyber768d00: NamedGroupT(.x25519_kyber768d00).PublicKey,

    const Self = @This();

    pub fn read(stream: anytype) !Self {
        var reader = stream.reader();
        const group = try stream.read(NamedGroup);
        const len = try stream.read(u16);
        switch (group) {
            // .x25519_kyber768d00 => {
            //     const expected_len = if (stream.is_client) @TypeOf(k).bytes_length else X25519Kyber768Draft.Kyber768.ciphertext_length;
            // },
            inline .secp256r1, .secp384r1 =>  |k| {
                const T = NamedGroupT(k).PublicKey;
                var buf: [T.compressed_sec1_encoded_length]u8 = undefined;
                try reader.readNoEof(&buf);
                const val = T.fromSec1(&buf) catch return Error.TlsDecryptError;
                return @unionInit(Self, @tagName(k), val);
            },
            .x25519 =>  {
                var res = Self{ .x25519 = undefined };
                if (res.x25519.len != len) return Error.TlsDecodeError;
                try reader.readNoEof(&res.x25519);
                return res;
            },
            else => {},
        }
        return .{ .invalid = {} };
    }

    pub fn write(self: Self, stream: anytype) !usize {
        var res: usize = 0;
        res += try stream.write(NamedGroup, self);
        const public = switch (self) {
            .x25519_kyber768d00 => |k| if (stream.is_client) &k.toBytes() else &k.ciphertext(),
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
    .x25519_kyber768d00,
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
    empty_renegotiation_info_scsv = 0x00ff,
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
    empty_renegotiation_info_scsv: void,

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
            .empty_renegotiation_info_scsv => return .{ .empty_renegotiation_info_scsv = {} },
            _ => return Error.TlsIllegalParameter,
        }
    }

    pub fn print(self: Self) void {
        switch (self) {
            .empty_renegotiation_info_scsv => {},
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
    empty_renegotiation_info_scsv: void,

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
            .empty_renegotiation_info_scsv => unreachable,
        }
    }

    pub fn print(self: Self) void {
        switch (self) {
            .empty_renegotiation_info_scsv => {},
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

    pub fn write(self: Self, stream: anytype) !usize {
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

    pub fn write(self: Self, stream: anytype) !usize {
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

    pub fn write(self: Self, stream: anytype) !usize {
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
    signature_algorithms_cert: void,
    key_share: []const KeyShare,
    none: void,

    const Self = @This();

    pub fn write(self: Self, stream: anytype) !usize {
        const PrefixLen = enum { zero, one, two };
        const prefix_len: PrefixLen = if (stream.is_client) switch (self) {
            .supported_versions,
            .ec_point_formats,
            .psk_key_exchange_modes => .one,
            .server_name,
            .supported_groups,
            .signature_algorithms,
            .key_share => .two,
            else => .zero,
        } else .zero;

        var res: usize  = 0;
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
                            }
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

        pub fn read(stream: anytype) @TypeOf(stream.*).ReadError!@This() {
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

    pub fn write(self: @This(), stream: anytype) !usize {
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

    /// Returns the number of bytes read. If the number read is smaller than
    /// `buffer.len`, it means the stream reached the end. Reaching the end of
    /// a stream is not an error condition.
    pub fn readAll(this: @This(), buffer: []u8) ReadError!usize {
        _ = .{ this, buffer };
        @panic("unimplemented");
    }

    /// Can be any error set.
    pub const WriteError = error{};

    /// Returns the number of bytes written, which may be less than the buffer space provided.
    pub fn writev(this: @This(), iovecs: []const std.os.iovec_const) WriteError!usize {
        _ = .{ this, iovecs };
        @panic("unimplemented");
    }

    /// The `iovecs` parameter is mutable in case this function needs to mutate
    /// the fields in order to handle partial writes from the underlying layer.
    pub fn writevAll(this: @This(), iovecs: []std.os.iovec_const) WriteError!void {
        // This can be implemented in terms of writev, or specialized if desired.
        _ = .{ this, iovecs };
        @panic("unimplemented");
    }
};

/// Abstraction over TLS record layer (RFC 8446 S5). StreamType MUST satisfy `StreamInterface`.
/// Cannot read and write at the same time.
///
/// Handles:
///   * Fragmentation
///   * Encryption and decryption of handshake and application data messages
///   * Reading and writing prefix length arrays
///   * Alerts
pub fn Stream(comptime fragment_size: usize, comptime StreamType: type) type {
    // TODO: Support RFC 6066 MaxFragmentLength and give fragment_size option to Client+Server.
    if (fragment_size > std.math.maxInt(u16)) @compileError("choose a smaller fragment_size");

    return struct {
        stream: *StreamType,
        /// > For concreteness, the transcript hash is always taken from the
        /// > following sequence of handshake messages, starting at the first
        /// > ClientHello and including only those messages that were sent:
        /// > ClientHello, HelloRetryRequest, ClientHello, ServerHello,
        /// > EncryptedExtensions, server CertificateRequest, server Certificate,
        /// > server CertificateVerify, server Finished, EndOfEarlyData, client
        /// > Certificate, client CertificateVerify, client Finished.
        transcript_hash: MultiHash = .{},
        /// Used for both reading and writing. Cannot be doing both at the same time.
        buffer: [fragment_size]u8 = undefined,
        /// Unread or unwritten view of `buffer`.
        view: []const u8 = "",

        /// When sending this is the record type that will be sent.
        /// When receiving this is the next fragment's expected record type.
        content_type: ContentType = .handshake,

        /// When receiving fragments this is the next expected fragment type.
        handshake_type: ?HandshakeType = .client_hello,

        /// Used to encrypt and decrypt .application_data messages until application_cipher is not null.
        handshake_cipher: ?HandshakeCipher = null,
        /// Used to encrypt and decrypt .application_data messages.
        application_cipher: ?ApplicationCipher = null,

        /// True when we send or receive a close_notify alert.
        closed: bool = false,

        /// Version to send out in record headers
        version: Version = .tls_1_0,

        /// True if we're being used as a client. This changes:
        ///     * Certain shared struct formats (like Extension)
        ///     * Which keys are used for encoding/decoding handshake and application messages.
        is_client: bool,

        /// When > 0 won't actually do anything with writes.
        /// This is to discover prefix lengths for record level spec-adherant sequential writing.
        nocommit: usize = 0,

       const Self = @This();

        pub const ReadError = StreamType.ReadError || Error || error{EndOfStream};
        pub const WriteError = StreamType.WriteError || error{
            TlsEncodeError,
        };

        fn ciphertextOverhead(self: Self) usize {
            if (self.application_cipher) |a| {
                switch (a) {
                    .empty_renegotiation_info_scsv => {},
                    inline else => |c| return @TypeOf(c).AEAD.tag_length + @sizeOf(ContentType),
                }
            }
            if (self.handshake_cipher) |a| {
                switch (a) {
                    .empty_renegotiation_info_scsv => {},
                    inline else => |c| return @TypeOf(c).AEAD.tag_length + @sizeOf(ContentType),
                }
            }
            return 0;
        }

        fn maxFragmentSize(self: Self) usize {
            return fragment_size - self.ciphertextOverhead();
        }

        const EncryptionMethod = enum { none, handshake, application };
        fn encryptionMethod(self: Self) EncryptionMethod {
            switch (self.content_type) {
                .change_cipher_spec => {},
                .handshake => {
                    if (self.handshake_cipher != null) return .handshake;
                },
                else => {
                    if (self.application_cipher != null) return .application;
                },
            }

            return .none;
        }

        pub fn flush(self: *Self) WriteError!void {
            if (self.view.len == 0) return;
            var plaintext = Plaintext{
                .type = self.content_type,
                .version = self.version,
                .length = @intCast(self.view.len),
            };

            if (self.application_cipher == null) {
                switch (self.content_type) {
                    .change_cipher_spec, .alert => {},
                    else => {
                        self.transcript_hash.update(self.view);
                    }
                }
            }

            var header: [fieldsLen(Plaintext)]u8 = undefined;
            var aead: []const u8 = "";
            switch (self.encryptionMethod()) {
                .none => {
                    header = Encoder.encode(Plaintext, plaintext);
                },
                .handshake => {
                    plaintext.type = .application_data;
                    plaintext.length += @intCast(self.ciphertextOverhead());
                    header = Encoder.encode(Plaintext, plaintext);
                    if (self.handshake_cipher) |*a| switch (a.*) {
                        .empty_renegotiation_info_scsv => {},
                        inline else => |*c| {
                            std.debug.assert(self.view.ptr == &self.buffer);
                            self.buffer[self.view.len] = @intFromEnum(self.content_type);
                            self.view = self.buffer[0..self.view.len + 1];
                            aead = &c.encrypt(self.view, &header, self.is_client, @constCast(self.view));
                        },
                    };
                },
                .application => {
                    plaintext.type = .application_data;
                    plaintext.length += @intCast(self.ciphertextOverhead());
                    header = Encoder.encode(Plaintext, plaintext);
                    if (self.application_cipher) |*a| switch (a.*) {
                        .empty_renegotiation_info_scsv => {},
                        inline else => |*c| {
                            std.debug.assert(self.view.ptr == &self.buffer);
                            self.buffer[self.view.len] = @intFromEnum(self.content_type);
                            self.view = self.buffer[0..self.view.len + 1];
                            aead = &c.encrypt(self.view, &header, self.is_client, @constCast(self.view));
                        },
                    };
                }
            }

            var iovecs = [_]std.os.iovec_const{
                .{ .iov_base = &header, .iov_len = header.len },
                .{ .iov_base = self.view.ptr, .iov_len = self.view.len },
                .{ .iov_base = aead.ptr, .iov_len = aead.len },
            };
            try self.stream.writevAll(&iovecs);
            self.view = self.buffer[0..0];
        }

        /// Write an alert to stream and call `close_notify` after. Returns Zig error.
        pub fn writeError(self: *Self, err: Alert.Description) Error {
            const alert = Alert{ .level = .fatal, .description = err };

            self.view = self.buffer[0..0];
            self.content_type = .alert;
            _ = self.write(Alert, alert) catch {};
            self.flush() catch {};

            self.close();
            @panic("writeError");
            // return err.toError();
        }

        pub fn close(self: *Self) void {
            const alert = Alert{ .level = .fatal, .description = .close_notify };
            _ = self.write(Alert, alert) catch {};
            self.content_type = .alert;
            self.flush() catch {};
            self.closed = true;
        }

        /// Write bytes to `stream`, potentially flushing once `self.buffer` is full.
        pub fn writeBytes(self: *Self, bytes: []const u8) WriteError!usize {
            if (self.nocommit > 0) return bytes.len;

            const available = self.buffer.len - self.view.len;
            const to_consume = bytes[0..@min(available, bytes.len)];

            @memcpy(self.buffer[self.view.len..][0..bytes.len], to_consume);
            self.view = self.buffer[0 .. self.view.len + to_consume.len];

            if (self.view.len == self.buffer.len) try self.flush();

            return to_consume.len;
        }

        pub fn writeAll(self: *Self, bytes: []const u8) WriteError!usize {
            var index: usize = 0;
            while (index != bytes.len) {
                index += try self.writeBytes(bytes[index..]);
            }
            return index;
        }

        pub fn writeArray(self: *Self, comptime PrefixT: type, comptime T: type, values: []const T) WriteError!usize {
            var res: usize = 0;
            for (values) |v| res += self.length(T, v);

            if (PrefixT != void) {
                if (res > std.math.maxInt(PrefixT)) {
                    self.close();
                    return error.TlsEncodeError; // Prefix length overflow
                }
                res += try self.write(PrefixT, @intCast(res));
            }

            for (values) |v| _ = try self.write(T, v);

            return res;
        }

        pub fn write(self: *Self, comptime T: type, value: T) WriteError!usize {
            switch (@typeInfo(T)) {
                .Int, .Enum => {
                    const encoded = Encoder.encode(T, value);
                    return try self.writeAll(&encoded);
                },
                .Struct, .Union => {
                    return try T.write(value, self);
                },
                .Void => return 0,
                else => @compileError("cannot write " ++ @typeName(T)),
            }
        }

        pub fn length(self: *Self, comptime T: type, value: T) usize {
            if (T == void) return 0;
            self.nocommit += 1;
            defer self.nocommit -= 1;
            return self.write(T, value) catch unreachable;
        }

        pub fn arrayLength(self: *Self, comptime PrefixT: type, comptime T: type, values: []const T,) usize {
            var res: usize = if (PrefixT == void) 0 else @divExact(@typeInfo(PrefixT).Int.bits, 8);
            for (values) |v| res += self.length(T, v);
            return res;
        }

        /// Reads bytes from `view`, potentially reading more fragments from `stream`.
        /// A return value of 0 indicates EOF.
        pub fn readBytes(self: *Self, buf: []u8) ReadError!usize {
            // > Any data received after a closure alert has been received MUST be ignored.
            if (self.eof()) return 0;

            var bytes_read: usize = 0;
            while (bytes_read != buf.len) {
                if (self.view.len == 0) try self.expectFragment(self.content_type, self.handshake_type);

                const to_read = @min(buf.len, self.view.len);
                @memcpy(buf[0..to_read], self.view[0..to_read]);

                self.view = self.view[to_read..];
                bytes_read += to_read;
            }

            return bytes_read;
        }

        /// Read fragment from `stream` into `buffer` and updates `self.view`. Returns message type.
        pub fn readFragment(self: *Self) ReadError!ContentType {
            std.debug.assert(self.view.len == 0); // last read should have completed
            var plaintext_header: [fieldsLen(Plaintext)]u8 = undefined;
            var n_read: usize = 0;

            var res: ContentType = .invalid;
            var len: u16 = 0;

            while (true) {
                n_read = try self.stream.readAll(&plaintext_header);
                if (n_read != plaintext_header.len) return self.writeError(.decode_error);

                // Take advantage of our `read` parsing code by setting view outside `self.buffer`.
                {
                    self.view = &plaintext_header;
                    errdefer self.view = self.buffer[0..0];
                    res = try self.read(ContentType);
                    _ = try self.read(Version);
                    len = try self.read(u16);
                    if (len > self.maxFragmentSize()) return self.writeError(.record_overflow);
                }

                self.view = self.buffer[0..len];
                n_read = try self.stream.readAll(@constCast(self.view));
                if (n_read != len) return self.writeError(.decode_error);

                const encryption_method = if (res == .application_data) self.encryptionMethod() else .none;
                switch (encryption_method) {
                    .none => {},
                    inline .handshake, .application => |t| {
                        switch (if (comptime t == .handshake) self.handshake_cipher.? else self.application_cipher.?) {
                            .empty_renegotiation_info_scsv => {},
                            inline else => |*p| {
                                const P = @TypeOf(p.*);
                                const tag_len = P.AEAD.tag_length;

                                const ciphertext = self.view[0..self.view.len - tag_len];
                                const tag = self.view[self.view.len - tag_len..][0..tag_len].*;
                                const out: []u8 = @constCast(self.view[0..ciphertext.len]);
                                p.decrypt(ciphertext, &plaintext_header, tag, self.is_client, out) catch
                                    return self.writeError(.bad_record_mac);
                                const padding_start = std.mem.lastIndexOfNone(u8, out, &[_]u8{0});
                                if (padding_start) |s| {
                                    res = @enumFromInt(self.view[s]);
                                    self.view = self.view[0..s];
                                } else {
                                    return self.writeError(.decode_error);
                                }
                            },
                        }
                    },
                }

                switch (res) {
                    .alert => {
                        const level = try self.read(Alert.Level);
                        const description = try self.read(Alert.Description);
                        std.log.debug("TLS alert {} {}", .{ level, description });

                        if (description == .close_notify) {
                            self.closed = true;
                            return res;
                        }
                        if (level == .fatal) return self.writeError(.unexpected_message);
                        continue;
                    },
                    // > An implementation may receive an unencrypted record of type
                    // > change_cipher_spec consisting of the single byte value 0x01 at any
                    // > time after the first ClientHello message has been sent or received
                    // > and before the peer's Finished message has been received and MUST
                    // > simply drop it without further processing.
                    .change_cipher_spec => {
                        if (!std.mem.eql(u8, self.view, &[_]u8{1})) return self.writeError(.unexpected_message);
                        continue;
                    },
                    else => {},
                }

                self.transcript_hash.update(self.view);

                return res;
            }
        }

        pub fn expectFragment(self: *Self, expected_content: ContentType, expected_handshake: ?HandshakeType,) ReadError!void {
            const actual_content = try self.readFragment();
            if (expected_content != actual_content) {
                std.debug.print("expected {} got {}\n", .{ expected_content, actual_content });
            }
            if (expected_handshake) |expected| {
                const actual_handshake = try self.read(HandshakeType);
                if (actual_handshake != expected) return self.writeError(.decode_error);
                const stated_len = try self.read(u24);
                if (stated_len != self.view.len) return self.writeError(.decode_error);
            }
        }

        pub fn expectHandshake(self: *Self) ReadError!Handshake.Header {
            try self.expectFragment(.handshake, null);
            const ty = try self.read(HandshakeType);
            const len = try self.read(u24);
            if (self.view.len != len) return self.writeError(.decode_error);
            return .{ .type = ty, .len = len };
        }

        pub fn read(self: *Self, comptime T: type) ReadError!T {
            comptime std.debug.assert(@sizeOf(T) < fragment_size);
            switch (@typeInfo(T)) {
                .Int => return self.reader().readInt(T, .big) catch |err| switch (err) {
                    error.EndOfStream => return self.writeError(.decode_error),
                    else => |e| return e,
                },
                .Enum => |info| {
                    if (info.is_exhaustive) @compileError("exhaustive enum cannot be used");
                    const int = try self.read(info.tag_type);
                    return @enumFromInt(int);
                },
                else => {
                    return T.read(self) catch |err| switch (err) {
                        error.EndOfStream, error.Full, error.ReadLengthInvalid => return self.writeError(.decode_error),
                        error.TlsUnexpectedMessage => return self.writeError(.unexpected_message),
                        error.TlsBadRecordMac => return self.writeError(.bad_record_mac),
                        error.TlsRecordOverflow => return self.writeError(.record_overflow),
                        error.TlsHandshakeFailure => return self.writeError(.handshake_failure),
                        error.TlsBadCertificate => return self.writeError(.bad_certificate),
                        error.TlsUnsupportedCertificate => return self.writeError(.unsupported_certificate),
                        error.TlsCertificateRevoked => return self.writeError(.certificate_revoked),
                        error.TlsCertificateExpired => return self.writeError(.certificate_expired),
                        error.TlsCertificateUnknown => return self.writeError(.certificate_unknown),
                        error.TlsIllegalParameter => return self.writeError(.illegal_parameter),
                        error.TlsUnknownCa => return self.writeError(.unknown_ca),
                        error.TlsAccessDenied => return self.writeError(.access_denied),
                        error.TlsDecodeError => return self.writeError(.decode_error),
                        error.TlsDecryptError => return self.writeError(.decrypt_error),
                        error.TlsProtocolVersion => return self.writeError(.protocol_version),
                        error.TlsInsufficientSecurity => return self.writeError(.insufficient_security),
                        error.TlsInternalError => return self.writeError(.internal_error),
                        error.TlsInappropriateFallback => return self.writeError(.inappropriate_fallback),
                        error.TlsMissingExtension => return self.writeError(.missing_extension),
                        error.TlsUnsupportedExtension => return self.writeError(.unsupported_extension),
                        error.TlsUnrecognizedName => return self.writeError(.unrecognized_name),
                        error.TlsBadCertificateStatusResponse => return self.writeError(.bad_certificate_status_response),
                        error.TlsUnknownPskIdentity => return self.writeError(.unknown_psk_identity),
                        error.TlsCertificateRequired => return self.writeError(.certificate_required),
                        error.TlsNoApplicationProtocol => return self.writeError(.no_application_protocol),
                        error.TlsUnknown => |e| {
                            self.close();
                            return e;
                        },
                    };
                },
            }
        }

        fn Iterator(comptime T: type) type {
            return struct {
                stream: *Self,
                end: usize,

                pub fn next(self: *@This()) ReadError!?T {
                    const cur_offset = self.stream.buffer.len - self.stream.view.len;
                    if (cur_offset > self.end) return null;
                    return try self.stream.read(T);
                }
            };
        }

        pub fn iterator(self: *Self, comptime Len: type, comptime Tag: type) ReadError!Iterator(Tag) {
            const offset = self.buffer.len - self.view.len;
            const len = try self.read(Len);
            return Iterator(Tag){
                .stream = self,
                .end = offset + len,
            };
        }

        pub fn extensions(self: *Self) ReadError!Iterator(Extension.Header) {
            return self.iterator(u16, Extension.Header);
        }

        pub fn eof(self: Self) bool {
            return self.closed and self.view.len == 0;
        }

        pub const Reader = std.io.Reader(*Self, ReadError, readBytes);
        pub const Writer = std.io.Writer(*Self, WriteError, writeBytes);

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

/// One of these potential hashes will be selected after receiving the other party's hello.
///
/// We init them before sending any messages to avoid having to store our first message until the
/// other party's handshake message returns. This message is usually larger than
/// `@sizeOf(MultiHash)` = 560
///
/// A nice benefit is decreased latency on hosts where one round trip takes longer than calling
/// `update` on each hashes.
pub const MultiHash = struct {
    sha256: sha2.Sha256 = sha2.Sha256.init(.{}),
    sha384: sha2.Sha384 = sha2.Sha384.init(.{}),
    sha512: sha2.Sha512 = sha2.Sha512.init(.{}),
    /// Chosen during handshake.
    active: enum { all, sha256, sha384, sha512 } = .all,

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
        }
    }

    pub fn setActive(self: *Self, cipher_suite: CipherSuite) void {
        self.active = switch (cipher_suite) {
            .aes_128_gcm_sha256, .chacha20_poly1305_sha256, .aegis_128l_sha256 => .sha256,
            .aes_256_gcm_sha384 => .sha384,
            .aegis_256_sha512 => .sha512,
            .empty_renegotiation_info_scsv => .all,
            _ => .all,
        };
    }

    pub inline fn peek(self: Self) []const u8 {
        return &switch (self.active) {
            .all => [_]u8{},
            .sha256 => self.sha256.peek(),
            .sha384 => self.sha384.peek(),
            .sha512 => self.sha512.peek(),
        };
    }
};

const Encoder = struct {
    fn RetType(comptime T: type) type {
        switch (@typeInfo(T)) {
            .Int => |info| switch (info.bits) {
                8 => return [1]u8,
                16 => return [2]u8,
                24 => return [3]u8,
                else => @compileError("unsupported int type: " ++ @typeName(T)),
            },
            .Enum => |info| {
                if (info.is_exhaustive) @compileError("exhaustive enum cannot be used");
                return RetType(info.tag_type);
            },
            .Struct => |info| {
                var len: usize = 0;
                inline for (info.fields) |f| len += @typeInfo(RetType(f.type)).Array.len;
                return [len]u8;
            },
            else => @compileError("don't know how to encode " ++ @tagName(T)),
        }
    }
    fn encode(comptime T: type, value: T) RetType(T) {
        return switch (@typeInfo(T)) {
            .Int => |info| switch (info.bits) {
                8 => .{value},
                16 => .{
                    @as(u8, @truncate(value >> 8)),
                    @as(u8, @truncate(value)),
                },
                24 => .{
                    @as(u8, @truncate(value >> 16)),
                    @as(u8, @truncate(value >> 8)),
                    @as(u8, @truncate(value)),
                },
                else => @compileError("unsupported int type: " ++ @typeName(T)),
            },
            .Enum => |info| encode(info.tag_type, @intFromEnum(value)),
            .Struct => |info| brk: {
                const Ret = RetType(T);

                var offset: usize = 0;
                var res: Ret = undefined;
                inline for (info.fields) |f| {
                    const encoded = encode(f.type, @field(value, f.name));
                    @memcpy(res[offset..][0..encoded.len], &encoded);
                    offset += encoded.len;
                }

                break :brk res;
            },
            else => @compileError("cannot encode type " ++ @typeName(T)),
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

        fn encrypt(
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

        fn decrypt(
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

        fn encrypt(
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

        fn decrypt(
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
    var buf = [_]u8{0x20} ** 64
        ++ "TLS 1.3, server CertificateVerify\x00".*
        ++ @as([max_digest_len]u8, undefined)
        ;
    @memcpy(buf[buf.len - max_digest_len..][0..digest.len], digest);

    return buf[0..buf.len - (max_digest_len - digest.len)];
}


fn fieldsLen(comptime T: type) comptime_int {
    var res: comptime_int = 0;
    inline for (std.meta.fields(T)) |f| res += @sizeOf(f.type);
    return res;
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
    pub const ReadError = Buffer.Error;
    pub const WriteError = Buffer.Error;
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{ .buffer = try Buffer.init(allocator, Plaintext.max_length) };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.buffer.deinit(allocator);
    }

    pub fn readAll(self: *Self, buffer: []u8) ReadError!usize {
        try self.buffer.readFirst(buffer, buffer.len);
        return buffer.len;
    }

    pub fn writev(self: *Self, iovecs: []const std.os.iovec_const) WriteError!usize {
        var res: usize = 0;
        for (iovecs) |i| {
            const slice = i.iov_base[0..i.iov_len];
            try self.buffer.writeSlice(slice);
            res += i.iov_len;
        }
        return res;
    }

    pub fn writevAll(self: *Self, iovecs: []std.os.iovec_const) WriteError!void {
        _ = try self.writev(iovecs);
    }

    pub fn peek(self: *Self, out: []u8) ReadError!void {
        const read_index = self.buffer.read_index;
        _ = try self.readAll(out);
        self.buffer.read_index = read_index;
    }
};

const TestHasher = struct {
    fn update(self: *@This(), bytes: []const u8) void {
        _ = .{ self, bytes };
    }
    fn peek(self: @This()) []const u8 {
        _ = .{self};
        return "";
    }
};

test "tls client and server handshake, data, and close_notify" {
    const allocator = std.testing.allocator;

    var inner_stream = try TestStream.init(allocator);
    defer inner_stream.deinit(allocator);

    const host = "example.ulfheim.net";
    var client = Client(@TypeOf(inner_stream)){
        .stream = Stream(Plaintext.max_length, TestStream){
            .stream = &inner_stream,
            .is_client = true,
        },
        .options = .{ .host = host, .ca_bundle = null, .allocator = allocator },
    };

    const server_der = @embedFile("./testdata/server.der");
    var server = Server(@TypeOf(inner_stream)){
        .stream = Stream(Plaintext.max_length, TestStream){
            .stream = &inner_stream,
            .is_client = false,
        },
        .options = .{
            // force this to use https://tls13.xargs.org/ as unit test for "server hello" onwards
            .cipher_suites = &[_]CipherSuite{.aes_256_gcm_sha384},
            .certificate = .{
                .entries = &[_]Certificate.Entry{
                    .{ .data = server_der },
                }
            }
        },
    };

    const session_id = [_]u8{
        0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee, 0xef,
        0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
    };
    const client_random = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
    };
    const server_random = [_]u8{
        0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f,
        0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
    };
    const client_x25519_seed = [_]u8{
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
    };
    const server_x25519_seed = [_]u8{
        0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f,
        0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf,
    };

    const key_pairs = try client_mod.KeyPairs.initAdvanced(
        client_random,
        session_id,
        client_x25519_seed ++ client_x25519_seed,
        client_x25519_seed,
        client_x25519_seed ++ [_]u8{0} ** (48-32),
        client_x25519_seed,
    );
    {
        // To get the same `hello_hash` as https://tls13.xargs.org/ just for
        // this test we send a mostly falsified client hello.
        // It doesn't matter because the server will be TLS 1.3 and only support .x25519
        const hello = ClientHello{
            .random = key_pairs.hello_rand,
            .session_id = &key_pairs.session_id,
            .cipher_suites = &[_]CipherSuite{
                .aes_256_gcm_sha384,
                .chacha20_poly1305_sha256,
                .aes_128_gcm_sha256,
                .empty_renegotiation_info_scsv,
            },
            .extensions = &.{
                .{ .server_name = &[_]ServerName{.{ .host_name = client.options.host }} },
                .{ .ec_point_formats = &[_]EcPointFormat{
                    .uncompressed,
                    .ansiX962_compressed_prime,
                    .ansiX962_compressed_char2,
                } },
                .{ .supported_groups = &[_]NamedGroup{
                    .x25519,
                    .secp256r1,
                    .x448,
                    .secp521r1,
                    .secp384r1,
                    .ffdhe2048,
                    .ffdhe3072,
                    .ffdhe4096,
                    .ffdhe6144,
                    .ffdhe8192,
                } },
                .{ .session_ticket = {} },
                .{ .encrypt_then_mac = {} },
                .{ .extended_master_secret = {} },
                .{ .signature_algorithms = &[_]SignatureScheme{
                    .ecdsa_secp256r1_sha256,
                    .ecdsa_secp384r1_sha384,
                    .ecdsa_secp521r1_sha512,
                    .ed25519,
                    .ed448,
                    .rsa_pss_pss_sha256,
                    .rsa_pss_pss_sha384,
                    .rsa_pss_pss_sha512,
                    .rsa_pss_rsae_sha256,
                    .rsa_pss_rsae_sha384,
                    .rsa_pss_rsae_sha512,
                    .rsa_pkcs1_sha256,
                    .rsa_pkcs1_sha384,
                    .rsa_pkcs1_sha512,
                } },
                .{ .supported_versions = &[_]Version{.tls_1_3} },
                .{ .psk_key_exchange_modes = &[_]PskKeyExchangeMode{.ke} },
                .{ .key_share = &[_]KeyShare{
                    .{ .x25519 = key_pairs.x25519.public_key },
                } },
            },
        };

        _ = try client.stream.write(Handshake, .{ .client_hello = hello });
        try client.stream.flush();
    }

    var tmp_buf: [Plaintext.max_length]u8 = undefined;
    {
        const buf = tmp_buf[0..inner_stream.buffer.len()];
        try inner_stream.peek(buf);

        const expected = [_]u8{
            0x16, // handshake
            0x03, 0x01, // tls 1.0 (lie for compat)
            0x00, 0xf8, // handshake len
            0x01, // client hello
            0x00, 0x00, 0xf4, // client hello len
            0x03, 0x03, // tls 1.2 (lie for compat)
        } ++ client_random ++
            [_]u8{session_id.len} ++ session_id ++
            [_]u8{
            0x00, 0x08, // cipher suite len
            0x13, 0x02, // aes_256_gcm_sha384
            0x13, 0x03, // chacha20_poly1305_sha256
            0x13, 0x01, // aes_128_gcm_sha256
            0x00, 0xff, // empty_renegotiation_info_scsv
            0x01, // compression methods len
            0x00, // none
            0x00, 0xa3, // extensions len
            0x00, 0x00, // server name ext
            0x00, 0x18, // server name len
            0x00, 0x16, // list entry len
            0x00, // dns hostname
        } ++
            Encoder.encode(u16, @intCast(host.len)) ++ host ++
            [_]u8{
            0x00, 0x0b, // ec point formats
            0x00, 0x04, // ext len
            0x03, // format type len
            0x00, // uncompresed
            0x01, // ansiX962_compressed_prime
            0x02, // ansiX962_compressed_char2
            0x00, 0x0a, // supported groups
            0x00, 0x16, // ext len
            0x00, 0x14, // supported groups len
            0x00, 0x1d, // x25519
            0x00, 0x17, // secp256r1
            0x00, 0x1e, // x448
            0x00, 0x19, // secp521r1
            0x00, 0x18, // secp384r1
            0x01, 0x00, // ffdhe2048
            0x01, 0x01, // ffdhe3072
            0x01, 0x02, // ffdhe4096
            0x01, 0x03, // ffdhe6144
            0x01, 0x04, // ffdhe8192
            0x00, 0x23, // session ticket
            0x00, 0x00, // ext len
            0x00, 0x16, // encrypt then mac
            0x00, 0x00, // ext len
            0x00, 0x17, // extended master secrets
            0x00, 0x00, // ext len
            0x00, 0x0d, // signature algos
            0x00, 0x1e, // ext len
            0x00, 0x1c, // algos len
            0x04, 0x03, // ecdsa_secp256r1_sha256
            0x05, 0x03, // ecdsa_secp384r1_sha384
            0x06, 0x03, // ecdsa_secp521r1_sha512
            0x08, 0x07, // ed25519
            0x08, 0x08, // ed448
            0x08, 0x09, // rsa_pss_pss_sha256
            0x08, 0x0a, // rsa_pss_pss_sha384
            0x08, 0x0b, // rsa_pss_pss_sha512
            0x08, 0x04, // rsa_pss_rsae_sha256
            0x08, 0x05, // rsa_pss_rsae_sha384
            0x08, 0x06, // rsa_pss_rsae_sha512
            0x04, 0x01, // rsa_pkcs1_sha256
            0x05, 0x01, // rsa_pkcs1_sha384
            0x06, 0x01, // rsa_pkcs1_sha512
            0x00, 0x2b, // supported versions
            0x00, 0x03, // ext len
            0x02, // supported versions len
            0x03, 0x04, // tls 1.3 (not lying anymore!)
            0x00, 0x2d, // psk key exchange modes
            0x00, 0x02, // ext len
            0x01, // psk key exchange modes len
            0x01, // PSK with (EC)DHE key establishment
            0x00, 0x33, // key share
            0x00, 0x26, // ext len
            0x00, 0x24, // key shares len
            0x00, 0x1d, // curve 25519
            0x00, 0x20, // key len
        } ++ key_pairs.x25519.public_key;
        try std.testing.expectEqualSlices(u8, expected, buf);
    }

    const client_hello = try server.recv_hello();
    try std.testing.expectEqualSlices(u8, &client_random, &client_hello.random);
    try std.testing.expectEqualSlices(u8, &session_id, &client_hello.session_id);
    const server_key_pair = server_mod.KeyPair{
        .random = server_random,
        .pair = .{ .x25519 = crypto.dh.X25519.KeyPair.create(server_x25519_seed) catch unreachable },
    };

    try server.send_hello(client_hello, server_key_pair);
    // hack to match xargs, need to fix server
    const signature_verify = [_]u8{
0x5c, 0xbb, 0x24, 0xc0, 0x40, 0x93, 0x32, 0xda, 0xa9, 0x20, 0xbb, 0xab, 0xbd, 0xb9, 0xbd, 0x50, 0x17, 0x0b, 0xe4, 0x9c, 0xfb, 0xe0, 0xa4, 0x10, 0x7f, 0xca, 0x6f, 0xfb, 0x10, 0x68, 0xe6, 0x5f, 0x96, 0x9e, 0x6d, 0xe7, 0xd4, 0xf9, 0xe5, 0x60, 0x38, 0xd6, 0x7c, 0x69, 0xc0, 0x31, 0x40, 0x3a, 0x7a, 0x7c, 0x0b, 0xcc, 0x86, 0x83, 0xe6, 0x57, 0x21, 0xa0, 0xc7, 0x2c, 0xc6, 0x63, 0x40, 0x19, 0xad, 0x1d, 0x3a, 0xd2, 0x65, 0xa8, 0x12, 0x61, 0x5b, 0xa3, 0x63, 0x80, 0x37, 0x20, 0x84, 0xf5, 0xda, 0xec, 0x7e, 0x63, 0xd3, 0xf4, 0x93, 0x3f, 0x27, 0x22, 0x74, 0x19, 0xa6, 0x11, 0x03, 0x46, 0x44, 0xdc, 0xdb, 0xc7, 0xbe, 0x3e, 0x74, 0xff, 0xac, 0x47, 0x3f, 0xaa, 0xad, 0xde, 0x8c, 0x2f, 0xc6, 0x5f, 0x32, 0x65, 0x77, 0x3e, 0x7e, 0x62, 0xde, 0x33, 0x86, 0x1f, 0xa7, 0x05, 0xd1, 0x9c, 0x50, 0x6e, 0x89, 0x6c, 0x8d, 0x82, 0xf5, 0xbc, 0xf3, 0x5f, 0xec, 0xe2, 0x59, 0xb7, 0x15, 0x38, 0x11, 0x5e, 0x9c, 0x8c, 0xfb, 0xa6, 0x2e, 0x49, 0xbb, 0x84, 0x74, 0xf5, 0x85, 0x87, 0xb1, 0x1b, 0x8a, 0xe3, 0x17, 0xc6, 0x33, 0xe9, 0xc7, 0x6c, 0x79, 0x1d, 0x46, 0x62, 0x84, 0xad, 0x9c, 0x4f, 0xf7, 0x35, 0xa6, 0xd2, 0xe9, 0x63, 0xb5, 0x9b, 0xbc, 0xa4, 0x40, 0xa3, 0x07, 0x09, 0x1a, 0x1b, 0x4e, 0x46, 0xbc, 0xc7, 0xa2, 0xf9, 0xfb, 0x2f, 0x1c, 0x89, 0x8e, 0xcb, 0x19, 0x91, 0x8b, 0xe4, 0x12, 0x1d, 0x7e, 0x8e, 0xd0, 0x4c, 0xd5, 0x0c, 0x9a, 0x59, 0xe9, 0x87, 0x98, 0x01, 0x07, 0xbb, 0xbf, 0x29, 0x9c, 0x23, 0x2e, 0x7f, 0xdb, 0xe1, 0x0a, 0x4c, 0xfd, 0xae, 0x5c, 0x89, 0x1c, 0x96, 0xaf, 0xdf, 0xf9, 0x4b, 0x54, 0xcc, 0xd2, 0xbc, 0x19, 0xd3, 0xcd, 0xaa, 0x66, 0x44, 0x85, 0x9c
    };
    _ = try server.stream.write(Handshake, Handshake{ .certificate_verify = CertificateVerify{
        .algorithm = .rsa_pss_rsae_sha256,
        .signature = &signature_verify,
    } });
    try server.stream.flush();

    try server.send_finished();
    {
        const buf = tmp_buf[0..inner_stream.buffer.len()];
        try inner_stream.peek(buf);

        const expected = [_]u8{
            0x16, // handshake
            0x03, 0x03, // tls 1.2
            0x00, 0x7a, // Handshake len
            0x02, // server hello
            0x00, 0x00, 0x76, // server hello len
            0x03, 0x03, // tls 1.2
        } ++ server_key_pair.random ++ [_]u8{session_id.len} ++ session_id ++
            [_]u8{
            0x13, 0x02, // aes_256_gcm_sha384
            0x00, // compression method
            0x00, 0x2e, // extensions len
            0x00, 0x2b, // supported versions
            0x00, 0x02, // ext len
            0x03, 0x04, // tls 1.3
            0x00, 0x33, // key share
            0x00, 0x24, // ext len
            0x00, 0x1d, // x25519
            0x00, 0x20, // key len
            0x9f, 0xd7,
            0xad, 0x6d,
            0xcf, 0xf4,
            0x29, 0x8d,
            0xd3, 0xf9,
            0x6d, 0x5b,
            0x1b, 0x2a,
            0xf9, 0x10,
            0xa0, 0x53,
            0x5b, 0x14,
            0x88, 0xd7,
            0xf8, 0xfa,
            0xbb, 0x34,
            0x9a, 0x98,
            0x28, 0x80,
            0xb6, 0x15, // key
        } ++
            [_]u8{
            0x14, // ChangeCipherSpec
            0x03, 0x03, // tls 1.2
            0x00, 0x01, // len
            0x01, // .change_cipher_spec
        } ++ [_]u8{
            0x17, // application data (lie for tls 1.2 compat)
            0x03, 0x03, // tls 1.2
            0x00, 0x17, // application data len
            0x6b, 0xe0,  0x2f, 0x9d, 0xa7, 0xc2, // encrypted data (empty EncryptedExtensions message)
            0xdc, // encrypted data type (handshake)
            0x9d, 0xde,  0xf5, 0x6f, 0x24, 0x68, 0xb9, 0x0a, // auth tag
            0xdf,  0xa2, 0x51, 0x01, 0xab, 0x03, 0x44, 0xae, // auth tag
        } ++ [_]u8{
            0x17, // application data (lie for tls 1.2 compat)
            0x03, 0x03, // tls 1.2
            0x03, 0x43, // application data len
            0xba, 0xf0, 0x0a, 0x9b, 0xe5, 0x0f, 0x3f, 0x23, 0x07, 0xe7, 0x26, 0xed, 0xcb, 0xda, 0xcb, 0xe4,
            0xb1, 0x86, 0x16, 0x44, 0x9d, 0x46, 0xc6, 0x20, 0x7a, 0xf6, 0xe9, 0x95, 0x3e, 0xe5, 0xd2, 0x41,
            0x1b, 0xa6, 0x5d, 0x31, 0xfe, 0xaf, 0x4f, 0x78, 0x76, 0x4f, 0x2d, 0x69, 0x39, 0x87, 0x18, 0x6c,
            0xc0, 0x13, 0x29, 0xc1, 0x87, 0xa5, 0xe4, 0x60, 0x8e, 0x8d, 0x27, 0xb3, 0x18, 0xe9, 0x8d, 0xd9,
            0x47, 0x69, 0xf7, 0x73, 0x9c, 0xe6, 0x76, 0x83, 0x92, 0xca, 0xca, 0x8d, 0xcc, 0x59, 0x7d, 0x77,
            0xec, 0x0d, 0x12, 0x72, 0x23, 0x37, 0x85, 0xf6, 0xe6, 0x9d, 0x6f, 0x43, 0xef, 0xfa, 0x8e, 0x79,
            0x05, 0xed, 0xfd, 0xc4, 0x03, 0x7e, 0xee, 0x59, 0x33, 0xe9, 0x90, 0xa7, 0x97, 0x2f, 0x20, 0x69,
            0x13, 0xa3, 0x1e, 0x8d, 0x04, 0x93, 0x13, 0x66, 0xd3, 0xd8, 0xbc, 0xd6, 0xa4, 0xa4, 0xd6, 0x47,
            0xdd, 0x4b, 0xd8, 0x0b, 0x0f, 0xf8, 0x63, 0xce, 0x35, 0x54, 0x83, 0x3d, 0x74, 0x4c, 0xf0, 0xe0,
            0xb9, 0xc0, 0x7c, 0xae, 0x72, 0x6d, 0xd2, 0x3f, 0x99, 0x53, 0xdf, 0x1f, 0x1c, 0xe3, 0xac, 0xeb,
            0x3b, 0x72, 0x30, 0x87, 0x1e, 0x92, 0x31, 0x0c, 0xfb, 0x2b, 0x09, 0x84, 0x86, 0xf4, 0x35, 0x38,
            0xf8, 0xe8, 0x2d, 0x84, 0x04, 0xe5, 0xc6, 0xc2, 0x5f, 0x66, 0xa6, 0x2e, 0xbe, 0x3c, 0x5f, 0x26,
            0x23, 0x26, 0x40, 0xe2, 0x0a, 0x76, 0x91, 0x75, 0xef, 0x83, 0x48, 0x3c, 0xd8, 0x1e, 0x6c, 0xb1,
            0x6e, 0x78, 0xdf, 0xad, 0x4c, 0x1b, 0x71, 0x4b, 0x04, 0xb4, 0x5f, 0x6a, 0xc8, 0xd1, 0x06, 0x5a,
            0xd1, 0x8c, 0x13, 0x45, 0x1c, 0x90, 0x55, 0xc4, 0x7d, 0xa3, 0x00, 0xf9, 0x35, 0x36, 0xea, 0x56,
            0xf5, 0x31, 0x98, 0x6d, 0x64, 0x92, 0x77, 0x53, 0x93, 0xc4, 0xcc, 0xb0, 0x95, 0x46, 0x70, 0x92,
            0xa0, 0xec, 0x0b, 0x43, 0xed, 0x7a, 0x06, 0x87, 0xcb, 0x47, 0x0c, 0xe3, 0x50, 0x91, 0x7b, 0x0a,
            0xc3, 0x0c, 0x6e, 0x5c, 0x24, 0x72, 0x5a, 0x78, 0xc4, 0x5f, 0x9f, 0x5f, 0x29, 0xb6, 0x62, 0x68,
            0x67, 0xf6, 0xf7, 0x9c, 0xe0, 0x54, 0x27, 0x35, 0x47, 0xb3, 0x6d, 0xf0, 0x30, 0xbd, 0x24, 0xaf,
            0x10, 0xd6, 0x32, 0xdb, 0xa5, 0x4f, 0xc4, 0xe8, 0x90, 0xbd, 0x05, 0x86, 0x92, 0x8c, 0x02, 0x06,
            0xca, 0x2e, 0x28, 0xe4, 0x4e, 0x22, 0x7a, 0x2d, 0x50, 0x63, 0x19, 0x59, 0x35, 0xdf, 0x38, 0xda,
            0x89, 0x36, 0x09, 0x2e, 0xef, 0x01, 0xe8, 0x4c, 0xad, 0x2e, 0x49, 0xd6, 0x2e, 0x47, 0x0a, 0x6c,
            0x77, 0x45, 0xf6, 0x25, 0xec, 0x39, 0xe4, 0xfc, 0x23, 0x32, 0x9c, 0x79, 0xd1, 0x17, 0x28, 0x76,
            0x80, 0x7c, 0x36, 0xd7, 0x36, 0xba, 0x42, 0xbb, 0x69, 0xb0, 0x04, 0xff, 0x55, 0xf9, 0x38, 0x50,
            0xdc, 0x33, 0xc1, 0xf9, 0x8a, 0xbb, 0x92, 0x85, 0x83, 0x24, 0xc7, 0x6f, 0xf1, 0xeb, 0x08, 0x5d,
            0xb3, 0xc1, 0xfc, 0x50, 0xf7, 0x4e, 0xc0, 0x44, 0x42, 0xe6, 0x22, 0x97, 0x3e, 0xa7, 0x07, 0x43,
            0x41, 0x87, 0x94, 0xc3, 0x88, 0x14, 0x0b, 0xb4, 0x92, 0xd6, 0x29, 0x4a, 0x05, 0x40, 0xe5, 0xa5,
            0x9c, 0xfa, 0xe6, 0x0b, 0xa0, 0xf1, 0x48, 0x99, 0xfc, 0xa7, 0x13, 0x33, 0x31, 0x5e, 0xa0, 0x83,
            0xa6, 0x8e, 0x1d, 0x7c, 0x1e, 0x4c, 0xdc, 0x2f, 0x56, 0xbc, 0xd6, 0x11, 0x96, 0x81, 0xa4, 0xad,
            0xbc, 0x1b, 0xbf, 0x42, 0xaf, 0xd8, 0x06, 0xc3, 0xcb, 0xd4, 0x2a, 0x07, 0x6f, 0x54, 0x5d, 0xee,
            0x4e, 0x11, 0x8d, 0x0b, 0x39, 0x67, 0x54, 0xbe, 0x2b, 0x04, 0x2a, 0x68, 0x5d, 0xd4, 0x72, 0x7e,
            0x89, 0xc0, 0x38, 0x6a, 0x94, 0xd3, 0xcd, 0x6e, 0xcb, 0x98, 0x20, 0xe9, 0xd4, 0x9a, 0xfe, 0xed,
            0x66, 0xc4, 0x7e, 0x6f, 0xc2, 0x43, 0xea, 0xbe, 0xbb, 0xcb, 0x0b, 0x02, 0x45, 0x38, 0x77, 0xf5,
            0xac, 0x5d, 0xbf, 0xbd, 0xf8, 0xdb, 0x10, 0x52, 0xa3, 0xc9, 0x94, 0xb2, 0x24, 0xcd, 0x9a, 0xaa,
            0xf5, 0x6b, 0x02, 0x6b, 0xb9, 0xef, 0xa2, 0xe0, 0x13, 0x02, 0xb3, 0x64, 0x01, 0xab, 0x64, 0x94,
            0xe7, 0x01, 0x8d, 0x6e, 0x5b, 0x57, 0x3b, 0xd3, 0x8b, 0xce, 0xf0, 0x23, 0xb1, 0xfc, 0x92, 0x94,
            0x6b, 0xbc, 0xa0, 0x20, 0x9c, 0xa5, 0xfa, 0x92, 0x6b, 0x49, 0x70, 0xb1, 0x00, 0x91, 0x03, 0x64,
            0x5c, 0xb1, 0xfc, 0xfe, 0x55, 0x23, 0x11, 0xff, 0x73, 0x05, 0x58, 0x98, 0x43, 0x70, 0x03, 0x8f,
            0xd2, 0xcc, 0xe2, 0xa9, 0x1f, 0xc7, 0x4d, 0x6f, 0x3e, 0x3e, 0xa9, 0xf8, 0x43, 0xee, 0xd3, 0x56,
            0xf6, 0xf8, 0x2d, 0x35, 0xd0, 0x3b, 0xc2, 0x4b, 0x81, 0xb5, 0x8c, 0xeb, 0x1a, 0x43, 0xec, 0x94,
            0x37, 0xe6, 0xf1, 0xe5, 0x0e, 0xb6, 0xf5, 0x55, 0xe3, 0x21, 0xfd, 0x67, 0xc8, 0x33, 0x2e, 0xb1,
            0xb8, 0x32, 0xaa, 0x8d, 0x79, 0x5a, 0x27, 0xd4, 0x79, 0xc6, 0xe2, 0x7d, 0x5a, 0x61, 0x03, 0x46,
            0x83, 0x89, 0x19, 0x03, 0xf6, 0x64, 0x21, 0xd0, 0x94, 0xe1, 0xb0, 0x0a, 0x9a, 0x13, 0x8d, 0x86,
            0x1e, 0x6f, 0x78, 0xa2, 0x0a, 0xd3, 0xe1, 0x58, 0x00, 0x54, 0xd2, 0xe3, 0x05, 0x25, 0x3c, 0x71,
            0x3a, 0x02, 0xfe, 0x1e, 0x28, 0xde, 0xee, 0x73, 0x36, 0x24, 0x6f, 0x6a, 0xe3, 0x43, 0x31, 0x80,
            0x6b, 0x46, 0xb4, 0x7b, 0x83, 0x3c, 0x39, 0xb9, 0xd3, 0x1c, 0xd3, 0x00, 0xc2, 0xa6, 0xed, 0x83,
            0x13, 0x99, 0x77, 0x6d, 0x07, 0xf5, 0x70, 0xea, 0xf0, 0x05, 0x9a, 0x2c, 0x68, 0xa5, 0xf3, 0xae,
            0x16, 0xb6, 0x17, 0x40, 0x4a, 0xf7, 0xb7, 0x23, 0x1a, 0x4d, 0x94, 0x27, 0x58, 0xfc, 0x02, 0x0b,
            0x3f, 0x23, 0xee, 0x8c, 0x15, 0xe3, 0x60, 0x44, 0xcf, 0xd6, 0x7c, 0xd6, 0x40, 0x99, 0x3b, 0x16,
            0x20, 0x75, 0x97, 0xfb, 0xf3, 0x85, 0xea, 0x7a, 0x4d, 0x99, 0xe8, 0xd4, 0x56, 0xff, 0x83, 0xd4,
            0x1f, 0x7b, 0x8b, 0x4f, 0x06, 0x9b, 0x02, 0x8a, 0x2a, 0x63, 0xa9, 0x19, 0xa7, 0x0e, 0x3a, 0x10,
            0xe3, 0x08, // encrypted cert
            0x41, // encrypted data type (Certificate)
            0x58, 0xfa, 0xa5, 0xba, 0xfa, 0x30, 0x18, 0x6c, // auth tag
            0x6b, 0x2f, 0x23, 0x8e, 0xb5, 0x30, 0xc7, 0x3e, // auth tag
        } ++ [_]u8{
            0x17, // application data (lie for tls 1.2 compat)
            0x03, 0x03, // tls 1.2
            0x01, 0x19, // application data len
            0x73, 0x71, 0x9f, 0xce, 0x07, 0xec, 0x2f, 0x6d, 0x3b, 0xba, 0x02, 0x92, 0xa0, 0xd4, 0x0b, 0x27,
            0x70, 0xc0, 0x6a, 0x27, 0x17, 0x99, 0xa5, 0x33, 0x14, 0xf6, 0xf7, 0x7f, 0xc9, 0x5c, 0x5f, 0xe7,
            0xb9, 0xa4, 0x32, 0x9f, 0xd9, 0x54, 0x8c, 0x67, 0x0e, 0xbe, 0xea, 0x2f, 0x2d, 0x5c, 0x35, 0x1d,
            0xd9, 0x35, 0x6e, 0xf2, 0xdc, 0xd5, 0x2e, 0xb1, 0x37, 0xbd, 0x3a, 0x67, 0x65, 0x22, 0xf8, 0xcd,
            0x0f, 0xb7, 0x56, 0x07, 0x89, 0xad, 0x7b, 0x0e, 0x3c, 0xab, 0xa2, 0xe3, 0x7e, 0x6b, 0x41, 0x99,
            0xc6, 0x79, 0x3b, 0x33, 0x46, 0xed, 0x46, 0xcf, 0x74, 0x0a, 0x9f, 0xa1, 0xfe, 0xc4, 0x14, 0xdc,
            0x71, 0x5c, 0x41, 0x5c, 0x60, 0xe5, 0x75, 0x70, 0x3c, 0xe6, 0xa3, 0x4b, 0x70, 0xb5, 0x19, 0x1a,
            0xa6, 0xa6, 0x1a, 0x18, 0xfa, 0xff, 0x21, 0x6c, 0x68, 0x7a, 0xd8, 0xd1, 0x7e, 0x12, 0xa7, 0xe9,
            0x99, 0x15, 0xa6, 0x11, 0xbf, 0xc1, 0xa2, 0xbe, 0xfc, 0x15, 0xe6, 0xe9, 0x4d, 0x78, 0x46, 0x42,
            0xe6, 0x82, 0xfd, 0x17, 0x38, 0x2a, 0x34, 0x8c, 0x30, 0x10, 0x56, 0xb9, 0x40, 0xc9, 0x84, 0x72,
            0x00, 0x40, 0x8b, 0xec, 0x56, 0xc8, 0x1e, 0xa3, 0xd7, 0x21, 0x7a, 0xb8, 0xe8, 0x5a, 0x88, 0x71,
            0x53, 0x95, 0x89, 0x9c, 0x90, 0x58, 0x7f, 0x72, 0xe8, 0xdd, 0xd7, 0x4b, 0x26, 0xd8, 0xed, 0xc1,
            0xc7, 0xc8, 0x37, 0xd9, 0xf2, 0xeb, 0xbc, 0x26, 0x09, 0x62, 0x21, 0x90, 0x38, 0xb0, 0x56, 0x54,
            0xa6, 0x3a, 0x0b, 0x12, 0x99, 0x9b, 0x4a, 0x83, 0x06, 0xa3, 0xdd, 0xcc, 0x0e, 0x17, 0xc5, 0x3b,
            0xa8, 0xf9, 0xc8, 0x03, 0x63, 0xf7, 0x84, 0x13, 0x54, 0xd2, 0x91, 0xb4, 0xac, 0xe0, 0xc0, 0xf3,
            0x30, 0xc0, 0xfc, 0xd5, 0xaa, 0x9d, 0xee, 0xf9, 0x69, 0xae, 0x8a, 0xb2, 0xd9, 0x8d, 0xa8, 0x8e,
            0xbb, 0x6e, 0xa8, 0x0a, 0x3a, 0x11, 0xf0, 0x0e, // encrypted signature_verify
            0xa2, // encrypted data type (SignatureVerify)
            0x96, 0xa3, 0x23, 0x23, 0x67, 0xff, 0x07, 0x5e, // auth tag
            0x1c, 0x66, 0xdd, 0x9c, 0xbe, 0xdc, 0x47, 0x13, // auth tag
        } ++ [_]u8{
            0x17, // application data (lie for tls 1.2 compat)
            0x03, 0x03, // tls 1.2
            0x00, 0x45, // application data len
            0x10, 0x61, 0xde, 0x27, 0xe5, 0x1c, 0x2c, 0x9f, 0x34, 0x29, 0x11, 0x80, 0x6f, 0x28, 0x2b, 0x71,
            0x0c, 0x10, 0x63, 0x2c, 0xa5, 0x00, 0x67, 0x55, 0x88, 0x0d, 0xbf, 0x70, 0x06, 0x00, 0x2d, 0x0e,
            0x84, 0xfe, 0xd9, 0xad, 0xf2, 0x7a, 0x43, 0xb5, 0x19, 0x23, 0x03, 0xe4, 0xdf, 0x5c, 0x28, 0x5d,
            0x58, 0xe3, 0xc7, 0x62,
            0x24, // encrypted data type (finished)
            0x07, 0x84, 0x40, 0xc0, 0x74, 0x23, 0x74, 0x74, // auth tag
            0x4a, 0xec, 0xf2, 0x8c, 0xf3, 0x18, 0x2f, 0xd0, // auth tag
        }
            ;
        try std.testing.expectEqualSlices(u8, &expected, buf);
    }

    try client.stream.expectFragment(.handshake, .server_hello);
    try client.recv_hello(key_pairs);
    {
        const s = server.stream.handshake_cipher.?.aes_256_gcm_sha384;
        const c = client.stream.handshake_cipher.?.aes_256_gcm_sha384;

        try std.testing.expectEqualSlices(u8, &s.handshake_secret, &c.handshake_secret);
        try std.testing.expectEqualSlices(u8, &s.master_secret, &c.master_secret);
        try std.testing.expectEqualSlices(u8, &s.server_finished_key, &c.server_finished_key);
        try std.testing.expectEqualSlices(u8, &s.client_finished_key, &c.client_finished_key);
        try std.testing.expectEqualSlices(u8, &s.server_key, &c.server_key);
        try std.testing.expectEqualSlices(u8, &s.client_key, &c.client_key);
        try std.testing.expectEqualSlices(u8, &s.server_iv, &c.server_iv);
        try std.testing.expectEqualSlices(u8, &s.client_iv, &c.client_iv);
        const client_iv = [_]u8{ 0x42,0x56,0xd2,0xe0,0xe8,0x8b,0xab,0xdd,0x05,0xeb,0x2f,0x27 };
        try std.testing.expectEqualSlices(u8, &client_iv, &c.client_iv);
    }
    try client.stream.expectFragment(.handshake, .encrypted_extensions);
    try client.recv_encrypted_extensions();
    try client.stream.expectFragment(.handshake, .certificate);
    const cert = try client.recv_certificate();
   defer allocator.free(cert.certificate.buffer);

    var digest = client.stream.transcript_hash.peek();
    try client.stream.expectFragment(.handshake, .certificate_verify);
    try client.recv_certificate_verify(digest, cert);

    digest = client.stream.transcript_hash.peek();
    try client.stream.expectFragment(.handshake, .finished);
    try client.recv_finished(digest);

    {
        const s = server.stream.application_cipher.?.aes_256_gcm_sha384;
        const c = client.stream.application_cipher.?.aes_256_gcm_sha384;

        try std.testing.expectEqualSlices(u8, &s.client_secret, &c.client_secret);
        try std.testing.expectEqualSlices(u8, &s.server_secret, &c.server_secret);
        try std.testing.expectEqualSlices(u8, &s.client_key, &c.client_key);
        try std.testing.expectEqualSlices(u8, &s.server_key, &c.server_key);
        try std.testing.expectEqualSlices(u8, &s.client_iv, &c.client_iv);
        try std.testing.expectEqualSlices(u8, &s.server_iv, &c.server_iv);
        const client_iv = [_]u8{ 0xbb,0x00,0x79,0x56,0xf4,0x74,0xb2,0x5d,0xe9,0x02,0x43,0x2f, };
        try std.testing.expectEqualSlices(u8, &client_iv, &c.client_iv);
    }

    try client.send_finished();
    {
        const buf = tmp_buf[0..inner_stream.buffer.len()];
        try inner_stream.peek(buf);

        const expected = [_]u8{
            0x14, // ChangeCipherSpec
            0x03, 0x03, // tls 1.2
            0x00, 0x01, // len
            0x01, // .change_cipher_spec
        }
       ++ [_]u8{
           0x17, // app data (lie for TLS 1.2)
           0x03, 0x03, // tls 1.2
           0x00, 0x45, // len
           0x9f, 0xf9, 0xb0, 0x63, 0x17, 0x51, 0x77, 0x32, 0x2a, 0x46, 0xdd, 0x98, 0x96, 0xf3, 0xc3, 0xbb,
           0x82, 0x0a, 0xb5, 0x17, 0x43, 0xeb, 0xc2, 0x5f, 0xda, 0xdd, 0x53, 0x45, 0x4b, 0x73, 0xde, 0xb5,
           0x4c, 0xc7, 0x24, 0x8d, 0x41, 0x1a, 0x18, 0xbc, 0xcf, 0x65, 0x7a, 0x96, 0x08, 0x24, 0xe9, 0xa1,
           0x93, 0x64, 0x83, 0x7c, // encrypted data
           0x35, // handshake
           0x0a, 0x69, 0xa8, 0x8d, 0x4b, 0xf6, 0x35, 0xc8, // auth tag
           0x5e, 0xb8, 0x74, 0xae, 0xbc, 0x9d, 0xfd, 0xe8, // auth tag
       }
            ;
        try std.testing.expectEqualSlices(u8, &expected, buf);
    }
    try server.recv_finished();

    _ = try client.stream.writer().writeAll("ping");
    try client.stream.flush();
    {
        const buf = tmp_buf[0..inner_stream.buffer.len()];
        try inner_stream.peek(buf);

        const expected = [_]u8{
           0x17, // app data (FOR REAL THIS TIME)
           0x03, 0x03, // tls 1.2
           0x00, 0x15, // len
            0x82, 0x81, 0x39, 0xcb, // ping
           0x7b, // app data (exciting!)
            0x73, 0xaa, 0xab, 0xf5, 0xb8, 0x2f, 0xbf, 0x9a, // auth tag
            0x29, 0x61, 0xbc, 0xde, 0x10, 0x03, 0x8a, 0x32, // auth tag
       }
            ;
        try std.testing.expectEqualSlices(u8, &expected, buf);
    }

    var recv_ping: [4]u8 = undefined;
    _ = try server.stream.reader().readAll(&recv_ping);
    try std.testing.expectEqualStrings("ping", &recv_ping);

    server.stream.close();
    try std.testing.expect(server.stream.closed);
    {
        const buf = tmp_buf[0..inner_stream.buffer.len()];
        try inner_stream.peek(buf);

        const expected = [_]u8{
           0x17, // app data (lie to encrypt)
           0x03, 0x03, // tls 1.2
           0x00, 0x13, // len
            0x3e, 0x2d, // alert
            0x99, // encrypted message type
            0x26, 0xbb, 0xfe, 0x1f, 0x46, 0xfb, 0x4e, 0xe2, // auth tag
            0x75, 0x1e, 0x53, 0xbf, 0xfc, 0x7e, 0x65, 0x16, // auth tag
       }
            ;
        try std.testing.expectEqualSlices(u8, &expected, buf);
    }

    _ = try client.stream.readFragment();
    try std.testing.expect(client.stream.closed);
}

test {
    _ = StreamInterface;
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

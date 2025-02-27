const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const crypto = std.crypto;
const Certificate = crypto.Certificate;

const Transcript = @import("transcript.zig").Transcript;
const PrivateKey = @import("PrivateKey.zig");
const record = @import("record.zig");
const rsa = @import("rsa/rsa.zig");
const proto = @import("protocol.zig");

const X25519 = crypto.dh.X25519;
const EcdsaP256Sha256 = crypto.sign.ecdsa.EcdsaP256Sha256;
const EcdsaP384Sha384 = crypto.sign.ecdsa.EcdsaP384Sha384;
const Kyber768 = crypto.kem.kyber_d00.Kyber768;
const MLKem768 = crypto.kem.ml_kem.MLKem768;

pub const supported_signature_algorithms = &[_]proto.SignatureScheme{
    .ecdsa_secp256r1_sha256,
    .ecdsa_secp384r1_sha384,
    .rsa_pss_rsae_sha256,
    .rsa_pss_rsae_sha384,
    .rsa_pss_rsae_sha512,
    .ed25519,
    .rsa_pkcs1_sha1,
    .rsa_pkcs1_sha256,
    .rsa_pkcs1_sha384,
};

pub const CertKeyPair = struct {
    /// A chain of one or more certificates, leaf first.
    ///
    /// Each X.509 certificate contains the public key of a key pair, extra
    /// information (the name of the holder, the name of an issuer of the
    /// certificate, validity time spans) and a signature generated using the
    /// private key of the issuer of the certificate.
    ///
    /// All certificates from the bundle are sent to the other side when creating
    /// Certificate tls message.
    ///
    /// Leaf certificate and private key are used to create signature for
    /// CertifyVerify tls message.
    bundle: Certificate.Bundle,

    /// Private key corresponding to the public key in leaf certificate from the
    /// bundle.
    key: PrivateKey,

    pub fn load(
        allocator: std.mem.Allocator,
        dir: std.fs.Dir,
        cert_path: []const u8,
        key_path: []const u8,
    ) !CertKeyPair {
        var bundle: Certificate.Bundle = .{};
        try bundle.addCertsFromFilePath(allocator, dir, cert_path);

        const key_file = try dir.openFile(key_path, .{});
        defer key_file.close();
        const key = try PrivateKey.fromFile(allocator, key_file);

        return .{ .bundle = bundle, .key = key };
    }

    pub fn deinit(c: *CertKeyPair, allocator: std.mem.Allocator) void {
        c.bundle.deinit(allocator);
    }
};

pub const CertBundle = struct {
    // A chain of one or more certificates.
    //
    // They are used to verify that certificate chain sent by the other side
    // forms valid trust chain.
    bundle: Certificate.Bundle = .{},

    pub fn fromFile(allocator: std.mem.Allocator, dir: std.fs.Dir, path: []const u8) !CertBundle {
        var bundle: Certificate.Bundle = .{};
        try bundle.addCertsFromFilePath(allocator, dir, path);
        return .{ .bundle = bundle };
    }

    pub fn fromSystem(allocator: std.mem.Allocator) !CertBundle {
        var bundle: Certificate.Bundle = .{};
        try bundle.rescan(allocator);
        return .{ .bundle = bundle };
    }

    pub fn deinit(cb: *CertBundle, allocator: std.mem.Allocator) void {
        cb.bundle.deinit(allocator);
    }
};

pub const CertificateBuilder = struct {
    bundle: Certificate.Bundle,
    key: PrivateKey,
    transcript: *Transcript,
    tls_version: proto.Version = .tls_1_3,
    side: proto.Side = .client,

    pub fn makeCertificate(h: CertificateBuilder, buf: []u8) ![]const u8 {
        var w = record.Writer{ .buf = buf };
        const certs = h.bundle.bytes.items;
        const certs_count = h.bundle.map.size;

        // Differences between tls 1.3 and 1.2
        // TLS 1.3 has request context in header and extensions for each certificate.
        // Here we use empty length for each field.
        // TLS 1.2 don't have these two fields.
        const request_context, const extensions = if (h.tls_version == .tls_1_3)
            .{ &[_]u8{0}, &[_]u8{ 0, 0 } }
        else
            .{ &[_]u8{}, &[_]u8{} };
        const certs_len = certs.len + (3 + extensions.len) * certs_count;

        // Write handshake header
        try w.writeHandshakeHeader(.certificate, certs_len + request_context.len + 3);
        try w.write(request_context);
        try w.writeInt(@as(u24, @intCast(certs_len)));

        // Write each certificate
        var index: u32 = 0;
        while (index < certs.len) {
            const e = try Certificate.der.Element.parse(certs, index);
            const cert = certs[index..e.slice.end];
            try w.writeInt(@as(u24, @intCast(cert.len))); // certificate length
            try w.write(cert); // certificate
            try w.write(extensions); // certificate extensions
            index = e.slice.end;
        }
        return w.getWritten();
    }

    pub fn makeCertificateVerify(h: CertificateBuilder, buf: []u8) ![]const u8 {
        var w = record.Writer{ .buf = buf };
        const signature, const signature_scheme = try h.createSignature();
        try w.writeHandshakeHeader(.certificate_verify, signature.len + 4);
        try w.writeEnum(signature_scheme);
        try w.writeInt(@as(u16, @intCast(signature.len)));
        try w.write(signature);
        return w.getWritten();
    }

    /// Creates signature for client certificate signature message.
    /// Returns signature bytes and signature scheme.
    inline fn createSignature(h: CertificateBuilder) !struct { []const u8, proto.SignatureScheme } {
        switch (h.key.signature_scheme) {
            inline .ecdsa_secp256r1_sha256,
            .ecdsa_secp384r1_sha384,
            => |comptime_scheme| {
                const Ecdsa = SchemeEcdsa(comptime_scheme);
                const key = h.key.key.ecdsa;
                const key_len = Ecdsa.SecretKey.encoded_length;
                if (key.len < key_len) return error.InvalidEncoding;
                const secret_key = try Ecdsa.SecretKey.fromBytes(key[0..key_len].*);
                const key_pair = try Ecdsa.KeyPair.fromSecretKey(secret_key);
                var signer = try key_pair.signer(null);
                h.setSignatureVerifyBytes(&signer);
                const signature = try signer.finalize();
                var buf: [Ecdsa.Signature.der_encoded_length_max]u8 = undefined;
                return .{ signature.toDer(&buf), comptime_scheme };
            },
            inline .rsa_pss_rsae_sha256,
            .rsa_pss_rsae_sha384,
            .rsa_pss_rsae_sha512,
            => |comptime_scheme| {
                const Hash = SchemeHash(comptime_scheme);
                var signer = try h.key.key.rsa.signerOaep(Hash, null);
                h.setSignatureVerifyBytes(&signer);
                var buf: [512]u8 = undefined;
                const signature = try signer.finalize(&buf);
                return .{ signature.bytes, comptime_scheme };
            },
            else => return error.TlsUnknownSignatureScheme,
        }
    }

    fn setSignatureVerifyBytes(h: CertificateBuilder, signer: anytype) void {
        if (h.tls_version == .tls_1_2) {
            // tls 1.2 signature uses current transcript hash value.
            // ref: https://datatracker.ietf.org/doc/html/rfc5246.html#section-7.4.8
            const Hash = @TypeOf(signer.h);
            signer.h = h.transcript.hash(Hash);
        } else {
            // tls 1.3 signature is computed over concatenation of 64 spaces,
            // context, separator and content.
            // ref: https://datatracker.ietf.org/doc/html/rfc8446#section-4.4.3
            if (h.side == .server) {
                signer.update(h.transcript.serverCertificateVerify());
            } else {
                signer.update(h.transcript.clientCertificateVerify());
            }
        }
    }

    fn SchemeEcdsa(comptime scheme: proto.SignatureScheme) type {
        return switch (scheme) {
            .ecdsa_secp256r1_sha256 => EcdsaP256Sha256,
            .ecdsa_secp384r1_sha384 => EcdsaP384Sha384,
            else => unreachable,
        };
    }
};

pub const CertificateParser = struct {
    pub_key_algo: Certificate.Parsed.PubKeyAlgo = undefined,
    pub_key_buf: [600]u8 = undefined,
    pub_key: []const u8 = undefined,

    signature_scheme: proto.SignatureScheme = @enumFromInt(0),
    signature_buf: [1024]u8 = undefined,
    signature: []const u8 = undefined,

    root_ca: Certificate.Bundle,
    host: []const u8,
    skip_verify: bool = false,
    now_sec: i64 = 0,

    pub fn parseCertificate(h: *CertificateParser, d: *record.Decoder, tls_version: proto.Version) !void {
        if (h.now_sec == 0) {
            h.now_sec = std.time.timestamp();
        }
        if (tls_version == .tls_1_3) {
            const request_context = try d.decode(u8);
            if (request_context != 0) return error.TlsIllegalParameter;
        }

        var trust_chain_established = false;
        var last_cert: ?Certificate.Parsed = null;
        const certs_len = try d.decode(u24);
        const start_idx = d.idx;
        while (d.idx - start_idx < certs_len) {
            const cert_len = try d.decode(u24);
            const cert = try d.slice(cert_len);
            if (tls_version == .tls_1_3) {
                // certificate extensions present in tls 1.3
                try d.skip(try d.decode(u16));
            }
            if (trust_chain_established)
                continue;

            const subject = try (Certificate{ .buffer = cert, .index = 0 }).parse();
            if (last_cert) |pc| {
                if (pc.verify(subject, h.now_sec)) {
                    last_cert = subject;
                } else |err| switch (err) {
                    error.CertificateIssuerMismatch => {
                        // skip certificate which is not part of the chain
                        continue;
                    },
                    else => return err,
                }
            } else { // first certificate
                if (!h.skip_verify and h.host.len > 0) {
                    try subject.verifyHostName(h.host);
                }
                h.pub_key = dupe(&h.pub_key_buf, subject.pubKey());
                h.pub_key_algo = subject.pub_key_algo;
                last_cert = subject;
            }
            if (!h.skip_verify) {
                if (h.root_ca.verify(last_cert.?, h.now_sec)) |_| {
                    trust_chain_established = true;
                } else |err| switch (err) {
                    error.CertificateIssuerNotFound => {},
                    else => return err,
                }
            }
        }
        if (!h.skip_verify and !trust_chain_established) {
            return error.CertificateIssuerNotFound;
        }
    }

    pub fn parseCertificateVerify(h: *CertificateParser, d: *record.Decoder) !void {
        h.signature_scheme = try d.decode(proto.SignatureScheme);
        h.signature = dupe(&h.signature_buf, try d.slice(try d.decode(u16)));
    }

    pub fn verifySignature(h: *CertificateParser, verify_bytes: []const u8) !void {
        switch (h.signature_scheme) {
            inline .ecdsa_secp256r1_sha256,
            .ecdsa_secp384r1_sha384,
            => |comptime_scheme| {
                if (h.pub_key_algo != .X9_62_id_ecPublicKey) return error.TlsBadSignatureScheme;
                const cert_named_curve = h.pub_key_algo.X9_62_id_ecPublicKey;
                switch (cert_named_curve) {
                    inline .secp384r1, .X9_62_prime256v1 => |comptime_cert_named_curve| {
                        const Ecdsa = SchemeEcdsaCert(comptime_scheme, comptime_cert_named_curve);
                        const key = try Ecdsa.PublicKey.fromSec1(h.pub_key);
                        const sig = try Ecdsa.Signature.fromDer(h.signature);
                        try sig.verify(verify_bytes, key);
                    },
                    else => return error.TlsUnknownSignatureScheme,
                }
            },
            .ed25519 => {
                if (h.pub_key_algo != .curveEd25519) return error.TlsBadSignatureScheme;
                const Eddsa = crypto.sign.Ed25519;
                if (h.signature.len != Eddsa.Signature.encoded_length) return error.InvalidEncoding;
                const sig = Eddsa.Signature.fromBytes(h.signature[0..Eddsa.Signature.encoded_length].*);
                if (h.pub_key.len != Eddsa.PublicKey.encoded_length) return error.InvalidEncoding;
                const key = try Eddsa.PublicKey.fromBytes(h.pub_key[0..Eddsa.PublicKey.encoded_length].*);
                try sig.verify(verify_bytes, key);
            },
            inline .rsa_pss_rsae_sha256,
            .rsa_pss_rsae_sha384,
            .rsa_pss_rsae_sha512,
            => |comptime_scheme| {
                if (h.pub_key_algo != .rsaEncryption) return error.TlsBadSignatureScheme;
                const Hash = SchemeHash(comptime_scheme);
                const pk = try rsa.PublicKey.fromDer(h.pub_key);
                const sig = rsa.Pss(Hash).Signature{ .bytes = h.signature };
                try sig.verify(verify_bytes, pk, null);
            },
            inline .rsa_pkcs1_sha1,
            .rsa_pkcs1_sha256,
            .rsa_pkcs1_sha384,
            .rsa_pkcs1_sha512,
            => |comptime_scheme| {
                if (h.pub_key_algo != .rsaEncryption) return error.TlsBadSignatureScheme;
                const Hash = SchemeHash(comptime_scheme);
                const pk = try rsa.PublicKey.fromDer(h.pub_key);
                const sig = rsa.PKCS1v1_5(Hash).Signature{ .bytes = h.signature };
                try sig.verify(verify_bytes, pk);
            },
            else => return error.TlsUnknownSignatureScheme,
        }
    }

    fn SchemeEcdsaCert(comptime scheme: proto.SignatureScheme, comptime cert_named_curve: Certificate.NamedCurve) type {
        const Sha256 = crypto.hash.sha2.Sha256;
        const Sha384 = crypto.hash.sha2.Sha384;
        const Ecdsa = crypto.sign.ecdsa.Ecdsa;

        return switch (scheme) {
            .ecdsa_secp256r1_sha256 => Ecdsa(cert_named_curve.Curve(), Sha256),
            .ecdsa_secp384r1_sha384 => Ecdsa(cert_named_curve.Curve(), Sha384),
            else => @compileError("bad scheme"),
        };
    }
};

fn SchemeHash(comptime scheme: proto.SignatureScheme) type {
    const Sha256 = crypto.hash.sha2.Sha256;
    const Sha384 = crypto.hash.sha2.Sha384;
    const Sha512 = crypto.hash.sha2.Sha512;

    return switch (scheme) {
        .rsa_pkcs1_sha1 => crypto.hash.Sha1,
        .rsa_pss_rsae_sha256, .rsa_pkcs1_sha256 => Sha256,
        .rsa_pss_rsae_sha384, .rsa_pkcs1_sha384 => Sha384,
        .rsa_pss_rsae_sha512, .rsa_pkcs1_sha512 => Sha512,
        else => @compileError("bad scheme"),
    };
}

pub fn dupe(buf: []u8, data: []const u8) []u8 {
    const n = @min(data.len, buf.len);
    @memcpy(buf[0..n], data[0..n]);
    return buf[0..n];
}

pub const DhKeyPair = struct {
    x25519_kp: X25519.KeyPair = undefined,
    secp256r1_kp: EcdsaP256Sha256.KeyPair = undefined,
    secp384r1_kp: EcdsaP384Sha384.KeyPair = undefined,
    kyber768_kp: Kyber768.KeyPair = undefined,
    ml_kem768: MLKem768.KeyPair = undefined,

    pub const seed_len = 32 + 32 + 48 + 64 + 64;

    pub fn init(seed: [seed_len]u8, named_groups: []const proto.NamedGroup) !DhKeyPair {
        var kp: DhKeyPair = .{};
        for (named_groups) |ng|
            switch (ng) {
                .x25519 => kp.x25519_kp = try X25519.KeyPair.generateDeterministic(seed[0..][0..X25519.seed_length].*),
                .secp256r1 => kp.secp256r1_kp = try EcdsaP256Sha256.KeyPair.generateDeterministic(seed[32..][0..EcdsaP256Sha256.KeyPair.seed_length].*),
                .secp384r1 => kp.secp384r1_kp = try EcdsaP384Sha384.KeyPair.generateDeterministic(seed[32 + 32 ..][0..EcdsaP384Sha384.KeyPair.seed_length].*),
                .x25519_kyber768d00 => kp.kyber768_kp = try Kyber768.KeyPair.generateDeterministic(seed[32 + 32 + 48 ..][0..Kyber768.seed_length].*),
                .x25519_ml_kem768 => kp.ml_kem768 = try MLKem768.KeyPair.generateDeterministic(seed[32 + 32 + 48 + 64 ..][0..MLKem768.seed_length].*),
                else => return error.TlsIllegalParameter,
            };
        return kp;
    }

    pub inline fn sharedKey(self: DhKeyPair, named_group: proto.NamedGroup, server_pub_key: []const u8) ![]const u8 {
        return switch (named_group) {
            .x25519 => brk: {
                if (server_pub_key.len != X25519.public_length)
                    return error.TlsIllegalParameter;
                break :brk &(try X25519.scalarmult(
                    self.x25519_kp.secret_key,
                    server_pub_key[0..X25519.public_length].*,
                ));
            },
            .secp256r1 => brk: {
                const pk = try EcdsaP256Sha256.PublicKey.fromSec1(server_pub_key);
                const mul = try pk.p.mulPublic(self.secp256r1_kp.secret_key.bytes, .big);
                break :brk &mul.affineCoordinates().x.toBytes(.big);
            },
            .secp384r1 => brk: {
                const pk = try EcdsaP384Sha384.PublicKey.fromSec1(server_pub_key);
                const mul = try pk.p.mulPublic(self.secp384r1_kp.secret_key.bytes, .big);
                break :brk &mul.affineCoordinates().x.toBytes(.big);
            },
            .x25519_kyber768d00 => brk: {
                const xksl = crypto.dh.X25519.public_length;
                const hksl = xksl + Kyber768.ciphertext_length;
                if (server_pub_key.len != hksl)
                    return error.TlsIllegalParameter;

                break :brk &((crypto.dh.X25519.scalarmult(
                    self.x25519_kp.secret_key,
                    server_pub_key[0..xksl].*,
                ) catch return error.TlsDecryptFailure) ++ (self.kyber768_kp.secret_key.decaps(
                    server_pub_key[xksl..hksl],
                ) catch return error.TlsDecryptFailure));
            },
            .x25519_ml_kem768 => brk: {
                const hksl = crypto.kem.ml_kem.MLKem768.ciphertext_length;
                const xksl = hksl + crypto.dh.X25519.public_length;
                if (server_pub_key.len != xksl) return error.TlsIllegalParameter;

                const hsk = self.ml_kem768.secret_key.decaps(server_pub_key[0..hksl]) catch
                    return error.TlsDecryptFailure;
                const xsk = crypto.dh.X25519.scalarmult(self.x25519_kp.secret_key, server_pub_key[hksl..xksl].*) catch
                    return error.TlsDecryptFailure;
                break :brk &(hsk ++ xsk);
            },
            else => return error.TlsIllegalParameter,
        };
    }

    // Returns 32, 65, 97 or 1216 bytes (keyber and ml_kem)
    pub inline fn publicKey(self: DhKeyPair, named_group: proto.NamedGroup) ![]const u8 {
        return switch (named_group) {
            .x25519 => &self.x25519_kp.public_key,
            .secp256r1 => &self.secp256r1_kp.public_key.toUncompressedSec1(),
            .secp384r1 => &self.secp384r1_kp.public_key.toUncompressedSec1(),
            .x25519_kyber768d00 => &self.x25519_kp.public_key ++ self.kyber768_kp.public_key.toBytes(),
            .x25519_ml_kem768 => &self.ml_kem768.public_key.toBytes() ++ self.x25519_kp.public_key,
            else => return error.TlsIllegalParameter,
        };
    }
};

const testing = std.testing;
const testu = @import("testu.zig");

test "DhKeyPair.x25519" {
    var seed: [DhKeyPair.seed_len]u8 = undefined;
    testu.fill(&seed);
    const server_pub_key = &testu.hexToBytes("3303486548531f08d91e675caf666c2dc924ac16f47a861a7f4d05919d143637");
    const expected = &testu.hexToBytes(
        \\ F1 67 FB 4A 49 B2 91 77  08 29 45 A1 F7 08 5A 21
        \\ AF FE 9E 78 C2 03 9B 81  92 40 72 73 74 7A 46 1E
    );
    const kp = try DhKeyPair.init(seed, &.{.x25519});
    try testing.expectEqualSlices(u8, expected, try kp.sharedKey(.x25519, server_pub_key));
}

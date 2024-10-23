const builtin = @import("builtin");
const std = @import("std");
const crypto = std.crypto;
const fmt = std.fmt;
const io = std.io;
const mem = std.mem;
const sha3 = crypto.hash.sha3;
const testing = std.testing;

const EncodingError = crypto.errors.EncodingError;
const IdentityElementError = crypto.errors.IdentityElementError;
const NonCanonicalError = crypto.errors.NonCanonicalError;
const SignatureVerificationError = crypto.errors.SignatureVerificationError;

/// ECDSA over P-256 with SHA-256.
pub const EcdsaP256Sha256 = Ecdsa(crypto.ecc.P256, crypto.hash.sha2.Sha256);
/// ECDSA over P-256 with SHA3-256.
pub const EcdsaP256Sha3_256 = Ecdsa(crypto.ecc.P256, crypto.hash.sha3.Sha3_256);
/// ECDSA over P-384 with SHA-384.
pub const EcdsaP384Sha384 = Ecdsa(crypto.ecc.P384, crypto.hash.sha2.Sha384);
/// ECDSA over P-384 with SHA3-384.
pub const EcdsaP256Sha3_384 = Ecdsa(crypto.ecc.P384, crypto.hash.sha3.Sha3_384);
/// ECDSA over Secp256k1 with SHA-256.
pub const EcdsaSecp256k1Sha256 = Ecdsa(crypto.ecc.Secp256k1, crypto.hash.sha2.Sha256);
/// ECDSA over Secp256k1 with SHA-256(SHA-256()) -- The Bitcoin signature system.
pub const EcdsaSecp256k1Sha256oSha256 = Ecdsa(crypto.ecc.Secp256k1, crypto.hash.composition.Sha256oSha256);

/// Elliptic Curve Digital Signature Algorithm (ECDSA).
pub fn Ecdsa(comptime Curve: type, comptime Hash: type) type {
    const Prf = switch (Hash) {
        sha3.Shake128 => sha3.KMac128,
        sha3.Shake256 => sha3.KMac256,
        else => crypto.auth.hmac.Hmac(Hash),
    };

    return struct {
        /// Length (in bytes) of optional random bytes, for non-deterministic signatures.
        pub const noise_length = Curve.scalar.encoded_length;

        /// An ECDSA secret key.
        pub const SecretKey = struct {
            /// Length (in bytes) of a raw secret key.
            pub const encoded_length = Curve.scalar.encoded_length;

            bytes: Curve.scalar.CompressedScalar,

            pub fn fromBytes(bytes: [encoded_length]u8) !SecretKey {
                return SecretKey{ .bytes = bytes };
            }

            pub fn toBytes(sk: SecretKey) [encoded_length]u8 {
                return sk.bytes;
            }
        };

        /// An ECDSA public key.
        pub const PublicKey = struct {
            /// Length (in bytes) of a compressed sec1-encoded key.
            pub const compressed_sec1_encoded_length = 1 + Curve.Fe.encoded_length;
            /// Length (in bytes) of a compressed sec1-encoded key.
            pub const uncompressed_sec1_encoded_length = 1 + 2 * Curve.Fe.encoded_length;

            p: Curve,

            /// Create a public key from a SEC-1 representation.
            pub fn fromSec1(sec1: []const u8) !PublicKey {
                return PublicKey{ .p = try Curve.fromSec1(sec1) };
            }

            /// Encode the public key using the compressed SEC-1 format.
            pub fn toCompressedSec1(pk: PublicKey) [compressed_sec1_encoded_length]u8 {
                return pk.p.toCompressedSec1();
            }

            /// Encoding the public key using the uncompressed SEC-1 format.
            pub fn toUncompressedSec1(pk: PublicKey) [uncompressed_sec1_encoded_length]u8 {
                return pk.p.toUncompressedSec1();
            }
        };

        /// An ECDSA signature.
        pub const Signature = struct {
            /// Length (in bytes) of a raw signature.
            pub const encoded_length = Curve.scalar.encoded_length * 2;
            /// Maximum length (in bytes) of a DER-encoded signature.
            pub const der_encoded_length_max = encoded_length + 2 + 2 * 3;

            /// The R component of an ECDSA signature.
            r: Curve.scalar.CompressedScalar,
            /// The S component of an ECDSA signature.
            s: Curve.scalar.CompressedScalar,

            /// Create a Verifier for incremental verification of a signature.
            pub fn verifier(self: Signature, public_key: PublicKey) (NonCanonicalError || EncodingError || IdentityElementError)!Verifier {
                return Verifier.init(self, public_key);
            }

            /// Verify the signature against a message and public key.
            /// Return IdentityElement or NonCanonical if the public key or signature are not in the expected range,
            /// or SignatureVerificationError if the signature is invalid for the given message and key.
            pub fn verify(self: Signature, msg: []const u8, public_key: PublicKey) (IdentityElementError || NonCanonicalError || SignatureVerificationError)!void {
                var st = try Verifier.init(self, public_key);
                st.update(msg);
                return st.verify();
            }

            /// Return the raw signature (r, s) in big-endian format.
            pub fn toBytes(self: Signature) [encoded_length]u8 {
                var bytes: [encoded_length]u8 = undefined;
                @memcpy(bytes[0 .. encoded_length / 2], &self.r);
                @memcpy(bytes[encoded_length / 2 ..], &self.s);
                return bytes;
            }

            /// Create a signature from a raw encoding of (r, s).
            /// ECDSA always assumes big-endian.
            pub fn fromBytes(bytes: [encoded_length]u8) Signature {
                return Signature{
                    .r = bytes[0 .. encoded_length / 2].*,
                    .s = bytes[encoded_length / 2 ..].*,
                };
            }

            /// Encode the signature using the DER format.
            /// The maximum length of the DER encoding is der_encoded_length_max.
            /// The function returns a slice, that can be shorter than der_encoded_length_max.
            pub fn toDer(self: Signature, buf: *[der_encoded_length_max]u8) []u8 {
                var fb = io.fixedBufferStream(buf);
                const w = fb.writer();
                const r_len = @as(u8, @intCast(self.r.len + (self.r[0] >> 7)));
                const s_len = @as(u8, @intCast(self.s.len + (self.s[0] >> 7)));
                const seq_len = @as(u8, @intCast(2 + r_len + 2 + s_len));
                w.writeAll(&[_]u8{ 0x30, seq_len }) catch unreachable;
                w.writeAll(&[_]u8{ 0x02, r_len }) catch unreachable;
                if (self.r[0] >> 7 != 0) {
                    w.writeByte(0x00) catch unreachable;
                }
                w.writeAll(&self.r) catch unreachable;
                w.writeAll(&[_]u8{ 0x02, s_len }) catch unreachable;
                if (self.s[0] >> 7 != 0) {
                    w.writeByte(0x00) catch unreachable;
                }
                w.writeAll(&self.s) catch unreachable;
                return fb.getWritten();
            }

            // Read a DER-encoded integer.
            fn readDerInt(out: []u8, reader: anytype) EncodingError!void {
                var buf: [2]u8 = undefined;
                _ = reader.readNoEof(&buf) catch return error.InvalidEncoding;
                if (buf[0] != 0x02) return error.InvalidEncoding;
                var expected_len = @as(usize, buf[1]);
                if (expected_len == 0 or expected_len > 1 + out.len) return error.InvalidEncoding;
                var has_top_bit = false;
                if (expected_len == 1 + out.len) {
                    if ((reader.readByte() catch return error.InvalidEncoding) != 0) return error.InvalidEncoding;
                    expected_len -= 1;
                    has_top_bit = true;
                }
                const out_slice = out[out.len - expected_len ..];
                reader.readNoEof(out_slice) catch return error.InvalidEncoding;
                if (has_top_bit and out[0] >> 7 == 0) return error.InvalidEncoding;
            }

            /// Create a signature from a DER representation.
            /// Returns InvalidEncoding if the DER encoding is invalid.
            pub fn fromDer(der: []const u8) EncodingError!Signature {
                var sig: Signature = mem.zeroInit(Signature, .{});
                var fb = io.fixedBufferStream(der);
                const reader = fb.reader();
                var buf: [2]u8 = undefined;
                _ = reader.readNoEof(&buf) catch return error.InvalidEncoding;
                if (buf[0] != 0x30 or @as(usize, buf[1]) + 2 != der.len) {
                    return error.InvalidEncoding;
                }
                try readDerInt(&sig.r, reader);
                try readDerInt(&sig.s, reader);
                if (fb.getPos() catch unreachable != der.len) return error.InvalidEncoding;

                return sig;
            }
        };

        /// A Signer is used to incrementally compute a signature.
        /// It can be obtained from a `KeyPair`, using the `signer()` function.
        pub const Signer = struct {
            h: Hash,
            secret_key: SecretKey,
            noise: ?[noise_length]u8,

            fn init(secret_key: SecretKey, noise: ?[noise_length]u8) !Signer {
                return Signer{
                    .h = Hash.init(.{}),
                    .secret_key = secret_key,
                    .noise = noise,
                };
            }

            /// Add new data to the message being signed.
            pub fn update(self: *Signer, data: []const u8) void {
                self.h.update(data);
            }

            /// Compute a signature over the entire message.
            pub fn finalize(self: *Signer) (IdentityElementError || NonCanonicalError)!Signature {
                const scalar_encoded_length = Curve.scalar.encoded_length;
                const h_len = @max(Hash.digest_length, scalar_encoded_length);
                var h: [h_len]u8 = [_]u8{0} ** h_len;
                const h_slice = h[h_len - Hash.digest_length .. h_len];
                self.h.final(h_slice);

                std.debug.assert(h.len >= scalar_encoded_length);
                const z = reduceToScalar(scalar_encoded_length, h[0..scalar_encoded_length].*);

                const k = deterministicScalar(h_slice.*, self.secret_key.bytes, self.noise);

                const p = try Curve.basePoint.mul(k.toBytes(.big), .big);
                const xs = p.affineCoordinates().x.toBytes(.big);
                const r = reduceToScalar(Curve.Fe.encoded_length, xs);
                if (r.isZero()) return error.IdentityElement;

                const k_inv = k.invert();
                const zrs = z.add(r.mul(try Curve.scalar.Scalar.fromBytes(self.secret_key.bytes, .big)));
                const s = k_inv.mul(zrs);
                if (s.isZero()) return error.IdentityElement;

                return Signature{ .r = r.toBytes(.big), .s = s.toBytes(.big) };
            }
        };

        /// A Verifier is used to incrementally verify a signature.
        /// It can be obtained from a `Signature`, using the `verifier()` function.
        pub const Verifier = struct {
            h: Hash,
            r: Curve.scalar.Scalar,
            s: Curve.scalar.Scalar,
            public_key: PublicKey,

            fn init(sig: Signature, public_key: PublicKey) (IdentityElementError || NonCanonicalError)!Verifier {
                const r = try Curve.scalar.Scalar.fromBytes(sig.r, .big);
                const s = try Curve.scalar.Scalar.fromBytes(sig.s, .big);
                if (r.isZero() or s.isZero()) return error.IdentityElement;

                return Verifier{
                    .h = Hash.init(.{}),
                    .r = r,
                    .s = s,
                    .public_key = public_key,
                };
            }

            /// Add new content to the message to be verified.
            pub fn update(self: *Verifier, data: []const u8) void {
                self.h.update(data);
            }

            /// Verify that the signature is valid for the entire message.
            pub fn verify(self: *Verifier) (IdentityElementError || NonCanonicalError || SignatureVerificationError)!void {
                const ht = Curve.scalar.encoded_length;
                const h_len = @max(Hash.digest_length, ht);
                var h: [h_len]u8 = [_]u8{0} ** h_len;
                self.h.final(h[h_len - Hash.digest_length .. h_len]);

                const z = reduceToScalar(ht, h[0..ht].*);
                if (z.isZero()) {
                    return error.SignatureVerificationFailed;
                }

                const s_inv = self.s.invert();
                const v1 = z.mul(s_inv).toBytes(.little);
                const v2 = self.r.mul(s_inv).toBytes(.little);
                const v1g = try Curve.basePoint.mulPublic(v1, .little);
                const v2pk = try self.public_key.p.mulPublic(v2, .little);
                const vxs = v1g.add(v2pk).affineCoordinates().x.toBytes(.big);
                const vr = reduceToScalar(Curve.Fe.encoded_length, vxs);
                if (!self.r.equivalent(vr)) {
                    return error.SignatureVerificationFailed;
                }
            }
        };

        /// An ECDSA key pair.
        pub const KeyPair = struct {
            /// Length (in bytes) of a seed required to create a key pair.
            pub const seed_length = noise_length;

            /// Public part.
            public_key: PublicKey,
            /// Secret scalar.
            secret_key: SecretKey,

            /// Create a new random key pair. `crypto.random.bytes` must be supported for the target.
            pub fn generate() IdentityElementError!KeyPair {
                var random_seed: [seed_length]u8 = undefined;
                crypto.random.bytes(&random_seed);
                return create(random_seed);
            }

            /// Create a new key pair. The seed must be secret and indistinguishable from random.
            pub fn create(seed: [seed_length]u8) IdentityElementError!KeyPair {
                const h = [_]u8{0x00} ** Hash.digest_length;
                const k0 = [_]u8{0x01} ** SecretKey.encoded_length;
                const secret_key = deterministicScalar(h, k0, seed).toBytes(.big);
                return fromSecretKey(SecretKey{ .bytes = secret_key });
            }

            /// Return the public key corresponding to the secret key.
            pub fn fromSecretKey(secret_key: SecretKey) IdentityElementError!KeyPair {
                const public_key = try Curve.basePoint.mul(secret_key.bytes, .big);
                return KeyPair{ .secret_key = secret_key, .public_key = PublicKey{ .p = public_key } };
            }

            /// Sign a message using the key pair.
            /// The noise can be null in order to create deterministic signatures.
            /// If deterministic signatures are not required, the noise should be randomly generated instead.
            /// This helps defend against fault attacks.
            pub fn sign(key_pair: KeyPair, msg: []const u8, noise: ?[noise_length]u8) (IdentityElementError || NonCanonicalError)!Signature {
                var st = try key_pair.signer(noise);
                st.update(msg);
                return st.finalize();
            }

            /// Create a Signer, that can be used for incremental signature verification.
            pub fn signer(key_pair: KeyPair, noise: ?[noise_length]u8) !Signer {
                return Signer.init(key_pair.secret_key, noise);
            }
        };

        // Reduce the coordinate of a field element to the scalar field.
        fn reduceToScalar(comptime unreduced_len: usize, s: [unreduced_len]u8) Curve.scalar.Scalar {
            if (unreduced_len >= 48) {
                var xs = [_]u8{0} ** 64;
                @memcpy(xs[xs.len - s.len ..], s[0..]);
                return Curve.scalar.Scalar.fromBytes64(xs, .big);
            }
            var xs = [_]u8{0} ** 48;
            @memcpy(xs[xs.len - s.len ..], s[0..]);
            return Curve.scalar.Scalar.fromBytes48(xs, .big);
        }

        // Create a deterministic scalar according to a secret key and optional noise.
        // This uses the overly conservative scheme from the "Deterministic ECDSA and EdDSA Signatures with Additional Randomness" draft.
        fn deterministicScalar(h: [Hash.digest_length]u8, secret_key: Curve.scalar.CompressedScalar, noise: ?[noise_length]u8) Curve.scalar.Scalar {
            var k = [_]u8{0x00} ** h.len;
            var m = [_]u8{0x00} ** (h.len + 1 + noise_length + secret_key.len + h.len);
            var t = [_]u8{0x00} ** Curve.scalar.encoded_length;
            const m_v = m[0..h.len];
            const m_i = &m[m_v.len];
            const m_z = m[m_v.len + 1 ..][0..noise_length];
            const m_x = m[m_v.len + 1 + noise_length ..][0..secret_key.len];
            const m_h = m[m.len - h.len ..];

            @memset(m_v, 0x01);
            m_i.* = 0x00;
            if (noise) |n| @memcpy(m_z, &n);
            @memcpy(m_x, &secret_key);
            @memcpy(m_h, &h);
            Prf.create(&k, &m, &k);
            Prf.create(m_v, m_v, &k);
            m_i.* = 0x01;
            Prf.create(&k, &m, &k);
            Prf.create(m_v, m_v, &k);
            while (true) {
                var t_off: usize = 0;
                while (t_off < t.len) : (t_off += m_v.len) {
                    const t_end = @min(t_off + m_v.len, t.len);
                    Prf.create(m_v, m_v, &k);
                    @memcpy(t[t_off..t_end], m_v[0 .. t_end - t_off]);
                }
                if (Curve.scalar.Scalar.fromBytes(t, .big)) |s| return s else |_| {}
                m_i.* = 0x00;
                Prf.create(&k, m[0 .. m_v.len + 1], &k);
                Prf.create(m_v, m_v, &k);
            }
        }
    };
}

test "Basic operations over EcdsaP384Sha384" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Scheme = EcdsaP384Sha384;
    const kp = try Scheme.KeyPair.generate();
    const msg = "test";

    var noise: [Scheme.noise_length]u8 = undefined;
    crypto.random.bytes(&noise);
    const sig = try kp.sign(msg, noise);
    try sig.verify(msg, kp.public_key);

    const sig2 = try kp.sign(msg, null);
    try sig2.verify(msg, kp.public_key);
}

test "Basic operations over Secp256k1" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Scheme = EcdsaSecp256k1Sha256oSha256;
    const kp = try Scheme.KeyPair.generate();
    const msg = "test";

    var noise: [Scheme.noise_length]u8 = undefined;
    crypto.random.bytes(&noise);
    const sig = try kp.sign(msg, noise);
    try sig.verify(msg, kp.public_key);

    const sig2 = try kp.sign(msg, null);
    try sig2.verify(msg, kp.public_key);
}

test "Basic operations over EcdsaP384Sha256" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Scheme = Ecdsa(crypto.ecc.P384, crypto.hash.sha2.Sha256);
    const kp = try Scheme.KeyPair.generate();
    const msg = "test";

    var noise: [Scheme.noise_length]u8 = undefined;
    crypto.random.bytes(&noise);
    const sig = try kp.sign(msg, noise);
    try sig.verify(msg, kp.public_key);

    const sig2 = try kp.sign(msg, null);
    try sig2.verify(msg, kp.public_key);
}

test "Verifying a existing signature with EcdsaP384Sha256" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Scheme = Ecdsa(crypto.ecc.P384, crypto.hash.sha2.Sha256);
    // zig fmt: off
    const sk_bytes = [_]u8{
    0x6a, 0x53, 0x9c, 0x83, 0x0f, 0x06, 0x86, 0xd9, 0xef, 0xf1, 0xe7, 0x5c, 0xae,
    0x93, 0xd9, 0x5b, 0x16, 0x1e, 0x96, 0x7c, 0xb0, 0x86, 0x35, 0xc9, 0xea, 0x20,
    0xdc, 0x2b, 0x02, 0x37, 0x6d, 0xd2, 0x89, 0x72, 0x0a, 0x37, 0xf6, 0x5d, 0x4f,
    0x4d, 0xf7, 0x97, 0xcb, 0x8b, 0x03, 0x63, 0xc3, 0x2d
    };
    const msg = [_]u8{
    0x64, 0x61, 0x74, 0x61, 0x20, 0x66, 0x6f, 0x72, 0x20, 0x73, 0x69, 0x67, 0x6e,
    0x69, 0x6e, 0x67, 0x0a
    };
    const sig_ans_bytes = [_]u8{
    0x30, 0x64, 0x02, 0x30, 0x7a, 0x31, 0xd8, 0xe0, 0xf8, 0x40, 0x7d, 0x6a, 0xf3,
    0x1a, 0x5d, 0x02, 0xe5, 0xcb, 0x24, 0x29, 0x1a, 0xac, 0x15, 0x94, 0xd1, 0x5b,
    0xcd, 0x75, 0x2f, 0x45, 0x79, 0x98, 0xf7, 0x60, 0x9a, 0xd5, 0xca, 0x80, 0x15,
    0x87, 0x9b, 0x0c, 0x27, 0xe3, 0x01, 0x8b, 0x73, 0x4e, 0x57, 0xa3, 0xd2, 0x9a,
    0x02, 0x30, 0x33, 0xe0, 0x04, 0x5e, 0x76, 0x1f, 0xc8, 0xcf, 0xda, 0xbe, 0x64,
    0x95, 0x0a, 0xd4, 0x85, 0x34, 0x33, 0x08, 0x7a, 0x81, 0xf2, 0xf6, 0xb6, 0x94,
    0x68, 0xc3, 0x8c, 0x5f, 0x88, 0x92, 0x27, 0x5e, 0x4e, 0x84, 0x96, 0x48, 0x42,
    0x84, 0x28, 0xac, 0x37, 0x93, 0x07, 0xd3, 0x50, 0x32, 0x71, 0xb0
    };
    // zig fmt: on

    const sk = try Scheme.SecretKey.fromBytes(sk_bytes);
    const kp = try Scheme.KeyPair.fromSecretKey(sk);

    const sig_ans = try Scheme.Signature.fromDer(&sig_ans_bytes);
    try sig_ans.verify(&msg, kp.public_key);

    const sig = try kp.sign(&msg, null);
    try sig.verify(&msg, kp.public_key);
}

const TestVector = struct {
    key: []const u8,
    msg: []const u8,
    sig: []const u8,
    result: enum { valid, invalid, acceptable },
};

test "Test vectors from Project Wycheproof" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const vectors = [_]TestVector{
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1802204cd60b855d442f5b3c7b11eb6c4e0ae7525fe710fab9aa7c77a67f79e6fadd76", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180220b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .acceptable },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30814502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3082004502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304602202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3085010000004502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308901000000000000004502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30847fffffff02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3084ffffffff02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3085ffffffffff02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3088ffffffffffffffff02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30ff02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502802ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18028000b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3047000002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0500", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304a498177304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30492500304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3047304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0004deadbeef", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304a222549817702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30492224250002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304d222202202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180004deadbeef022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304a02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e182226498177022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304902202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1822252500022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304d02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e182223022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0004deadbeef", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304daa00bb00cd00304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304baa02aabb304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304d2228aa00bb00cd0002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304b2226aa02aabb02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304d02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e182229aa00bb00cd00022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304b02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e182227aa02aabb022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3081", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3080304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3049228002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180000022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304902202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e182280022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3080314502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3049228003202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180000022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304902202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e182280032100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "0500", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "2e4502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "2f4502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "314502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "324502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "ff4502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30493001023044202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3044202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db00", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db05000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db060811220000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000fe02beef", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "308002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0002beef", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3047300002202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db3000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304802202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847dbbf7f00", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3047304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302202202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "306802202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30460281202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304602202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1802812100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3047028200202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180282002100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502212ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3045021f2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022200b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022000b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304a028501000000202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304a02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180285010000002100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304e02890100000000000000202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304e02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18028901000000000000002100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304902847fffffff2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304902202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1802847fffffff00b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30490284ffffffff2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304902202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180284ffffffff00b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304a0285ffffffffff2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304a02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180285ffffffffff00b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304d0288ffffffffffffffff2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304d02202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180288ffffffffffffffff00b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502ff2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1802ff00b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3023022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302402022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302302202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1802", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702222ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180000022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022300b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3047022200002ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180223000000b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180000022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702222ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180500022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304702202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022300b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db0500", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30250281022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180281", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30250500022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180500", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304500202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304501202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304503202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304504202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3045ff202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18002100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18012100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18032100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18042100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18ff2100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30250200022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180200", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3049222402012b021fa3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304902202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1822250201000220b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3045022029a3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022102b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e98022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b491568475b", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3044021f2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3044021fa3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022000b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30460221ff2ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304602202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180222ff00b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026090180022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18090180", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020100022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "302502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30460221012ba3a8bd6b94d5ed80a6d9d1190a436ebccc0833490686deac8635bcb9bf5369022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30460221ff2ba3a8bf6b94d5eb80a6d9d1190a436f42fe12d7fad749d4c512a036c0f908c7022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30450220d45c5741946b2a137f59262ee6f5bc91001af27a5e1117a64733950642a3d1e8022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100d45c5740946b2a147f59262ee6f5bc90bd01ed280528b62b3aed5fc93f06f739022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30460221fed45c5742946b2a127f59262ee6f5bc914333f7ccb6f979215379ca434640ac97022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30460221012ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100d45c5741946b2a137f59262ee6f5bc91001af27a5e1117a64733950642a3d1e8022100b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022101b329f478a2bbd0a6c384ee1493b1f518276e0e4a5375928d6fcd160c11cb6d2c", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180220b329f47aa2bbd0a4c384ee1493b1f518ada018ef05465583885980861905228a", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180221ff4cd60b865d442f5a3c7b11eb6c4e0ae79578ec6353a20bf783ecb4b6ea97b825", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e180221fe4cd60b875d442f593c7b11eb6c4e0ae7d891f1b5ac8a6d729032e9f3ee3492d4", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304502202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e18022101b329f479a2bbd0a5c384ee1493b1f5186a87139cac5df4087c134b49156847db", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "304402202ba3a8be6b94d5ec80a6d9d1190a436effe50d85a1eee859b8cc6af9bd5c2e1802204cd60b865d442f5a3c7b11eb6c4e0ae79578ec6353a20bf783ecb4b6ea97b825", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3006020100020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3006020100020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30060201000201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020100022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020100022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020100022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020100022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020100022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3008020100090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3006020100090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3006020101020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3006020101020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30060201010201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020101022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020101022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020101022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020101022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026020101022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3008020101090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3006020101090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30060201ff020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30060201ff020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30060201ff0201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30260201ff022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30260201ff022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30260201ff022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30260201ff022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30260201ff022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30080201ff090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30060201ff090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325510201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3028022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325500201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3028022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325520201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3028022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff0201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3028022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000001000000000000000000000001000000000000000000000000020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000001000000000000000000000001000000000000000000000000020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff000000010000000000000000000000010000000000000000000000000201ff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000001000000000000000000000000022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000001000000000000000000000000022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632550", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000001000000000000000000000000022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632552", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000001000000000000000000000000022100ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000001000000000000000000000000022100ffffffff00000001000000000000000000000001000000000000000000000000", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3028022100ffffffff00000001000000000000000000000001000000000000000000000000090380fe01", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3026022100ffffffff00000001000000000000000000000001000000000000000000000000090142", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30060201010c0130", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30050201010c00", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30090c0225730c03732573", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "30080201013003020100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3003020101", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313233343030", .sig = "3006020101010100", .result = .invalid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3639383139", .sig = "3044022064a1aab5000d0e804f3e2fc02bdee9be8ff312334e2ba16d11547c97711c898e02206af015971cc30be6d1a206d4e013e0997772a2f91d73286ffd683b9bb2cf4f1b", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "343236343739373234", .sig = "3044022016aea964a2f6506d6f78c81c91fc7e8bded7d397738448de1e19a0ec580bf2660220252cd762130c6667cfe8b7bc47d27d78391e8e80c578d1cd38c3ff033be928e9", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "37313338363834383931", .sig = "30450221009cc98be2347d469bf476dfc26b9b733df2d26d6ef524af917c665baccb23c8820220093496459effe2d8d70727b82462f61d0ec1b7847929d10ea631dacb16b56c32", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3130333539333331363638", .sig = "3044022073b3c90ecd390028058164524dde892703dce3dea0d53fa8093999f07ab8aa4302202f67b0b8e20636695bb7d8bf0a651c802ed25a395387b5f4188c0c4075c88634", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33393439343031323135", .sig = "3046022100bfab3098252847b328fadf2f89b95c851a7f0eb390763378f37e90119d5ba3dd022100bdd64e234e832b1067c2d058ccb44d978195ccebb65c2aaf1e2da9b8b4987e3b", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31333434323933303739", .sig = "30440220204a9784074b246d8bf8bf04a4ceb1c1f1c9aaab168b1596d17093c5cd21d2cd022051cce41670636783dc06a759c8847868a406c2506fe17975582fe648d1d88b52", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33373036323131373132", .sig = "3046022100ed66dc34f551ac82f63d4aa4f81fe2cb0031a91d1314f835027bca0f1ceeaa0302210099ca123aa09b13cd194a422e18d5fda167623c3f6e5d4d6abb8953d67c0c48c7", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "333433363838373132", .sig = "30450220060b700bef665c68899d44f2356a578d126b062023ccc3c056bf0f60a237012b0221008d186c027832965f4fcc78a3366ca95dedbb410cbef3f26d6be5d581c11d3610", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31333531353330333730", .sig = "30460221009f6adfe8d5eb5b2c24d7aa7934b6cf29c93ea76cd313c9132bb0c8e38c96831d022100b26a9c9e40e55ee0890c944cf271756c906a33e66b5bd15e051593883b5e9902", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "36353533323033313236", .sig = "3045022100a1af03ca91677b673ad2f33615e56174a1abf6da168cebfa8868f4ba273f16b7022020aa73ffe48afa6435cd258b173d0c2377d69022e7d098d75caf24c8c5e06b1c", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31353634333436363033", .sig = "3045022100fdc70602766f8eed11a6c99a71c973d5659355507b843da6e327a28c11893db902203df5349688a085b137b1eacf456a9e9e0f6d15ec0078ca60a7f83f2b10d21350", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "34343239353339313137", .sig = "3046022100b516a314f2fce530d6537f6a6c49966c23456f63c643cf8e0dc738f7b876e675022100d39ffd033c92b6d717dd536fbc5efdf1967c4bd80954479ba66b0120cd16fff2", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3130393533323631333531", .sig = "304402203b2cbf046eac45842ecb7984d475831582717bebb6492fd0a485c101e29ff0a802204c9b7b47a98b0f82de512bc9313aaf51701099cac5f76e68c8595fc1c1d99258", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "35393837333530303431", .sig = "3044022030c87d35e636f540841f14af54e2f9edd79d0312cfa1ab656c3fb15bfde48dcf022047c15a5a82d24b75c85a692bd6ecafeb71409ede23efd08e0db9abf6340677ed", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33343633303036383738", .sig = "3044022038686ff0fda2cef6bc43b58cfe6647b9e2e8176d168dec3c68ff262113760f520220067ec3b651f422669601662167fa8717e976e2db5e6a4cf7c2ddabb3fde9d67d", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "39383137333230323837", .sig = "3044022044a3e23bf314f2b344fc25c7f2de8b6af3e17d27f5ee844b225985ab6e2775cf02202d48e223205e98041ddc87be532abed584f0411f5729500493c9cc3f4dd15e86", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33323232303431303436", .sig = "304402202ded5b7ec8e90e7bf11f967a3d95110c41b99db3b5aa8d330eb9d638781688e902207d5792c53628155e1bfc46fb1a67e3088de049c328ae1f44ec69238a009808f9", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "36363636333037313034", .sig = "3046022100bdae7bcb580bf335efd3bc3d31870f923eaccafcd40ec2f605976f15137d8b8f022100f6dfa12f19e525270b0106eecfe257499f373a4fb318994f24838122ce7ec3c7", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31303335393531383938", .sig = "3045022050f9c4f0cd6940e162720957ffff513799209b78596956d21ece251c2401f1c6022100d7033a0a787d338e889defaaabb106b95a4355e411a59c32aa5167dfab244726", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31383436353937313935", .sig = "3045022100f612820687604fa01906066a378d67540982e29575d019aabe90924ead5c860d02203f9367702dd7dd4f75ea98afd20e328a1a99f4857b316525328230ce294b0fef", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33313336303436313839", .sig = "30460221009505e407657d6e8bc93db5da7aa6f5081f61980c1949f56b0f2f507da5782a7a022100c60d31904e3669738ffbeccab6c3656c08e0ed5cb92b3cfa5e7f71784f9c5021", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "32363633373834323534", .sig = "3046022100bbd16fbbb656b6d0d83e6a7787cd691b08735aed371732723e1c68a40404517d0221009d8e35dba96028b7787d91315be675877d2d097be5e8ee34560e3e7fd25c0f00", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31363532313030353234", .sig = "304402202ec9760122db98fd06ea76848d35a6da442d2ceef7559a30cf57c61e92df327e02207ab271da90859479701fccf86e462ee3393fb6814c27b760c4963625c0a19878", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "35373438303831363936", .sig = "3044022054e76b7683b6650baa6a7fc49b1c51eed9ba9dd463221f7a4f1005a89fe00c5902202ea076886c773eb937ec1cc8374b7915cfd11b1c1ae1166152f2f7806a31c8fd", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "36333433393133343638", .sig = "304402205291deaf24659ffbbce6e3c26f6021097a74abdbb69be4fb10419c0c496c9466022065d6fcf336d27cc7cdb982bb4e4ecef5827f84742f29f10abf83469270a03dc3", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31353431313033353938", .sig = "30450220207a3241812d75d947419dc58efb05e8003b33fc17eb50f9d15166a88479f107022100cdee749f2e492b213ce80b32d0574f62f1c5d70793cf55e382d5caadf7592767", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3130343738353830313238", .sig = "304502206554e49f82a855204328ac94913bf01bbe84437a355a0a37c0dee3cf81aa7728022100aea00de2507ddaf5c94e1e126980d3df16250a2eaebc8be486effe7f22b4f929", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3130353336323835353638", .sig = "3046022100a54c5062648339d2bff06f71c88216c26c6e19b4d80a8c602990ac82707efdfc022100e99bbe7fcfafae3e69fd016777517aa01056317f467ad09aff09be73c9731b0d", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "393533393034313035", .sig = "3045022100975bd7157a8d363b309f1f444012b1a1d23096593133e71b4ca8b059cff37eaf02207faa7a28b1c822baa241793f2abc930bd4c69840fe090f2aacc46786bf919622", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "393738383438303339", .sig = "304402205694a6f84b8f875c276afd2ebcfe4d61de9ec90305afb1357b95b3e0da43885e02200dffad9ffd0b757d8051dec02ebdf70d8ee2dc5c7870c0823b6ccc7c679cbaa4", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33363130363732343432", .sig = "3045022100a0c30e8026fdb2b4b4968a27d16a6d08f7098f1a98d21620d7454ba9790f1ba602205e470453a8a399f15baf463f9deceb53acc5ca64459149688bd2760c65424339", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31303534323430373035", .sig = "30440220614ea84acf736527dd73602cd4bb4eea1dfebebd5ad8aca52aa0228cf7b99a880220737cc85f5f2d2f60d1b8183f3ed490e4de14368e96a9482c2a4dd193195c902f", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "35313734343438313937", .sig = "3045022100bead6734ebe44b810d3fb2ea00b1732945377338febfd439a8d74dfbd0f942fa02206bb18eae36616a7d3cad35919fd21a8af4bbe7a10f73b3e036a46b103ef56e2a", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31393637353631323531", .sig = "30440220499625479e161dacd4db9d9ce64854c98d922cbf212703e9654fae182df9bad2022042c177cf37b8193a0131108d97819edd9439936028864ac195b64fca76d9d693", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33343437323533333433", .sig = "3045022008f16b8093a8fb4d66a2c8065b541b3d31e3bfe694f6b89c50fb1aaa6ff6c9b20221009d6455e2d5d1779748573b611cb95d4a21f967410399b39b535ba3e5af81ca2e", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "333638323634333138", .sig = "3046022100be26231b6191658a19dd72ddb99ed8f8c579b6938d19bce8eed8dc2b338cb5f8022100e1d9a32ee56cffed37f0f22b2dcb57d5c943c14f79694a03b9c5e96952575c89", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33323631313938363038", .sig = "3045022015e76880898316b16204ac920a02d58045f36a229d4aa4f812638c455abe0443022100e74d357d3fcb5c8c5337bd6aba4178b455ca10e226e13f9638196506a1939123", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "39363738373831303934", .sig = "30440220352ecb53f8df2c503a45f9846fc28d1d31e6307d3ddbffc1132315cc07f16dad02201348dfa9c482c558e1d05c5242ca1c39436726ecd28258b1899792887dd0a3c6", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "34393538383233383233", .sig = "304402204a40801a7e606ba78a0da9882ab23c7677b8642349ed3d652c5bfa5f2a9558fb02203a49b64848d682ef7f605f2832f7384bdc24ed2925825bf8ea77dc5981725782", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "383234363337383337", .sig = "3045022100eacc5e1a8304a74d2be412b078924b3bb3511bac855c05c9e5e9e44df3d61e9602207451cd8e18d6ed1885dd827714847f96ec4bb0ed4c36ce9808db8f714204f6d1", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3131303230383333373736", .sig = "304502202f7a5e9e5771d424f30f67fdab61e8ce4f8cd1214882adb65f7de94c31577052022100ac4e69808345809b44acb0b2bd889175fb75dd050c5a449ab9528f8f78daa10c", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "313333383731363438", .sig = "3045022100ffcda40f792ce4d93e7e0f0e95e1a2147dddd7f6487621c30a03d710b3300219022079938b55f8a17f7ed7ba9ade8f2065a1fa77618f0b67add8d58c422c2453a49a", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "333232313434313632", .sig = "304602210081f2359c4faba6b53d3e8c8c3fcc16a948350f7ab3a588b28c17603a431e39a8022100cd6f6a5cc3b55ead0ff695d06c6860b509e46d99fccefb9f7f9e101857f74300", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3130363836363535353436", .sig = "3045022100dfc8bf520445cbb8ee1596fb073ea283ea130251a6fdffa5c3f5f2aaf75ca8080220048e33efce147c9dd92823640e338e68bfd7d0dc7a4905b3a7ac711e577e90e7", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "3632313535323436", .sig = "3046022100ad019f74c6941d20efda70b46c53db166503a0e393e932f688227688ba6a576202210093320eb7ca0710255346bdbb3102cdcf7964ef2e0988e712bc05efe16c199345", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "37303330383138373734", .sig = "3046022100ac8096842e8add68c34e78ce11dd71e4b54316bd3ebf7fffdeb7bd5a3ebc1883022100f5ca2f4f23d674502d4caf85d187215d36e3ce9f0ce219709f21a3aac003b7a8", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "35393234353233373434", .sig = "30440220677b2d3a59b18a5ff939b70ea002250889ddcd7b7b9d776854b4943693fb92f702206b4ba856ade7677bf30307b21f3ccda35d2f63aee81efd0bab6972cc0795db55", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31343935353836363231", .sig = "30450220479e1ded14bcaed0379ba8e1b73d3115d84d31d4b7c30e1f05e1fc0d5957cfb0022100918f79e35b3d89487cf634a4f05b2e0c30857ca879f97c771e877027355b2443", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "34303035333134343036", .sig = "3044022043dfccd0edb9e280d9a58f01164d55c3d711e14b12ac5cf3b64840ead512a0a302201dbe33fa8ba84533cd5c4934365b3442ca1174899b78ef9a3199f49584389772", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "33303936343537353132", .sig = "304402205b09ab637bd4caf0f4c7c7e4bca592fea20e9087c259d26a38bb4085f0bbff11022045b7eb467b6748af618e9d80d6fdcd6aa24964e5a13f885bca8101de08eb0d75", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "32373834303235363230", .sig = "304502205e9b1c5a028070df5728c5c8af9b74e0667afa570a6cfa0114a5039ed15ee06f022100b1360907e2d9785ead362bb8d7bd661b6c29eeffd3c5037744edaeb9ad990c20", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "32363138373837343138", .sig = "304502200671a0a85c2b72d54a2fb0990e34538b4890050f5a5712f6d1a7a5fb8578f32e022100db1846bab6b7361479ab9c3285ca41291808f27fd5bd4fdac720e5854713694c", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "31363432363235323632", .sig = "304402207673f8526748446477dbbb0590a45492c5d7d69859d301abbaedb35b2095103a02203dc70ddf9c6b524d886bed9e6af02e0e4dec0d417a414fed3807ef4422913d7c", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "36383234313839343336", .sig = "304402207f085441070ecd2bb21285089ebb1aa6450d1a06c36d3ff39dfd657a796d12b50220249712012029870a2459d18d47da9aa492a5e6cb4b2d8dafa9e4c5c54a2b9a8b", .result = .valid },
        .{ .key = "042927b10512bae3eddcfe467828128bad2903269919f7086069c8c4df6c732838c7787964eaac00e5921fb1498a60f4606766b3d9685001558d1a974e7341513e", .msg = "343834323435343235", .sig = "3046022100914c67fb61dd1e27c867398ea7322d5ab76df04bc5aa6683a8e0f30a5d287348022100fa07474031481dda4953e3ac1959ee8cea7e66ec412b38d6c96d28f6d37304ea", .result = .valid },
        .{ .key = "040ad99500288d466940031d72a9f5445a4d43784640855bf0a69874d2de5fe103c5011e6ef2c42dcd50d5d3d29f99ae6eba2c80c9244f4c5422f0979ff0c3ba5e", .msg = "313233343030", .sig = "303502104319055358e8617b0c46353d039cdaab022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc63254e", .result = .valid },
        .{ .key = "040ad99500288d466940031d72a9f5445a4d43784640855bf0a69874d2de5fe103c5011e6ef2c42dcd50d5d3d29f99ae6eba2c80c9244f4c5422f0979ff0c3ba5e", .msg = "313233343030", .sig = "3046022100ffffffff00000001000000000000000000000000fffffffffffffffffffffffc022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc63254e", .result = .invalid },
        .{ .key = "04ab05fd9d0de26b9ce6f4819652d9fc69193d0aa398f0fba8013e09c58220455419235271228c786759095d12b75af0692dd4103f19f6a8c32f49435a1e9b8d45", .msg = "313233343030", .sig = "3046022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc63254f022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc63254e", .result = .valid },
        .{ .key = "0480984f39a1ff38a86a68aa4201b6be5dfbfecf876219710b07badf6fdd4c6c5611feb97390d9826e7a06dfb41871c940d74415ed3cac2089f1445019bb55ed95", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100909135bdb6799286170f5ead2de4f6511453fe50914f3df2de54a36383df8dd4", .result = .valid },
        .{ .key = "044201b4272944201c3294f5baa9a3232b6dd687495fcc19a70a95bc602b4f7c0595c37eba9ee8171c1bb5ac6feaf753bc36f463e3aef16629572c0c0a8fb0800e", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022027b4577ca009376f71303fd5dd227dcef5deb773ad5f5a84360644669ca249a5", .result = .valid },
        .{ .key = "04a71af64de5126a4a4e02b7922d66ce9415ce88a4c9d25514d91082c8725ac9575d47723c8fbe580bb369fec9c2665d8e30a435b9932645482e7c9f11e872296b", .msg = "313233343030", .sig = "3006020105020101", .result = .valid },
        .{ .key = "046627cec4f0731ea23fc2931f90ebe5b7572f597d20df08fc2b31ee8ef16b15726170ed77d8d0a14fc5c9c3c4c9be7f0d3ee18f709bb275eaf2073e258fe694a5", .msg = "313233343030", .sig = "3006020105020103", .result = .valid },
        .{ .key = "045a7c8825e85691cce1f5e7544c54e73f14afc010cb731343262ca7ec5a77f5bfef6edf62a4497c1bd7b147fb6c3d22af3c39bfce95f30e13a16d3d7b2812f813", .msg = "313233343030", .sig = "3006020105020105", .result = .valid },
        .{ .key = "04cbe0c29132cd738364fedd603152990c048e5e2fff996d883fa6caca7978c73770af6a8ce44cb41224b2603606f4c04d188e80bff7cc31ad5189d4ab0d70e8c1", .msg = "313233343030", .sig = "3006020105020106", .result = .valid },
        .{ .key = "04cbe0c29132cd738364fedd603152990c048e5e2fff996d883fa6caca7978c73770af6a8ce44cb41224b2603606f4c04d188e80bff7cc31ad5189d4ab0d70e8c1", .msg = "313233343030", .sig = "3026022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632556020106", .result = .invalid },
        .{ .key = "044be4178097002f0deab68f0d9a130e0ed33a6795d02a20796db83444b037e13920f13051e0eecdcfce4dacea0f50d1f247caa669f193c1b4075b51ae296d2d56", .msg = "313233343030", .sig = "3026020105022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc75fbd8", .result = .invalid },
        .{ .key = "04d0f73792203716afd4be4329faa48d269f15313ebbba379d7783c97bf3e890d9971f4a3206605bec21782bf5e275c714417e8f566549e6bc68690d2363c89cc1", .msg = "313233343030", .sig = "3027020201000221008f1e3c7862c58b16bb76eddbb76eddbb516af4f63f2d74d76e0d28c9bb75ea88", .result = .valid },
        .{ .key = "044838b2be35a6276a80ef9e228140f9d9b96ce83b7a254f71ccdebbb8054ce05ffa9cbc123c919b19e00238198d04069043bd660a828814051fcb8aac738a6c6b", .msg = "313233343030", .sig = "302c02072d9b4d347952d6022100ef3043e7329581dbb3974497710ab11505ee1c87ff907beebadd195a0ffe6d7a", .result = .valid },
        .{ .key = "047393983ca30a520bbc4783dc9960746aab444ef520c0a8e771119aa4e74b0f64e9d7be1ab01a0bf626e709863e6a486dbaf32793afccf774e2c6cd27b1857526", .msg = "313233343030", .sig = "3032020d1033e67e37b32b445580bf4eff0221008b748b74000000008b748b748b748b7466e769ad4a16d3dcd87129b8e91d1b4d", .result = .valid },
        .{ .key = "045ac331a1103fe966697379f356a937f350588a05477e308851b8a502d5dfcdc5fe9993df4b57939b2b8da095bf6d794265204cfe03be995a02e65d408c871c0b", .msg = "313233343030", .sig = "302702020100022100ef9f6ba4d97c09d03178fa20b4aaad83be3cf9cb824a879fec3270fc4b81ef5b", .result = .valid },
        .{ .key = "041d209be8de2de877095a399d3904c74cc458d926e27bb8e58e5eae5767c41509dd59e04c214f7b18dce351fc2a549893a6860e80163f38cc60a4f2c9d040d8c9", .msg = "313233343030", .sig = "3032020d062522bbd3ecbe7c39e93e7c25022100ef9f6ba4d97c09d03178fa20b4aaad83be3cf9cb824a879fec3270fc4b81ef5b", .result = .valid },
        .{ .key = "04083539fbee44625e3acaafa2fcb41349392cef0633a1b8fabecee0c133b10e99915c1ebe7bf00df8535196770a58047ae2a402f26326bb7d41d4d7616337911e", .msg = "313233343030", .sig = "3045022100ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6324d50220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70", .result = .valid },
        .{ .key = "048aeb368a7027a4d64abdea37390c0c1d6a26f399e2d9734de1eb3d0e1937387405bd13834715e1dbae9b875cf07bd55e1b6691c7f7536aef3b19bf7a4adf576d", .msg = "313233343030", .sig = "30250220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70020101", .result = .valid },
        .{ .key = "048aeb368a7027a4d64abdea37390c0c1d6a26f399e2d9734de1eb3d0e1937387405bd13834715e1dbae9b875cf07bd55e1b6691c7f7536aef3b19bf7a4adf576d", .msg = "313233343030", .sig = "30250220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70020100", .result = .invalid },
        .{ .key = "04b533d4695dd5b8c5e07757e55e6e516f7e2c88fa0239e23f60e8ec07dd70f2871b134ee58cc583278456863f33c3a85d881f7d4a39850143e29d4eaf009afe47", .msg = "313233343030", .sig = "304402207fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a80220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70", .result = .invalid },
        .{ .key = "04f50d371b91bfb1d7d14e1323523bc3aa8cbf2c57f9e284de628c8b4536787b86f94ad887ac94d527247cd2e7d0c8b1291c553c9730405380b14cbb209f5fa2dd", .msg = "313233343030", .sig = "304402207fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a902207fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a8", .result = .valid },
        .{ .key = "0468ec6e298eafe16539156ce57a14b04a7047c221bafc3a582eaeb0d857c4d94697bed1af17850117fdb39b2324f220a5698ed16c426a27335bb385ac8ca6fb30", .msg = "313233343030", .sig = "304402207fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a902207fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a9", .result = .valid },
        .{ .key = "0469da0364734d2e530fece94019265fefb781a0f1b08f6c8897bdf6557927c8b866d2d3c7dcd518b23d726960f069ad71a933d86ef8abbcce8b20f71e2a847002", .msg = "313233343030", .sig = "30450220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70022100bb5a52f42f9c9261ed4361f59422a1e30036e7c32b270c8807a419feca605023", .result = .valid },
        .{ .key = "04d8adc00023a8edc02576e2b63e3e30621a471e2b2320620187bf067a1ac1ff3233e2b50ec09807accb36131fff95ed12a09a86b4ea9690aa32861576ba2362e1", .msg = "313233343030", .sig = "30440220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70022044a5ad0ad0636d9f12bc9e0a6bdd5e1cbcb012ea7bf091fcec15b0c43202d52e", .result = .valid },
        .{ .key = "043623ac973ced0a56fa6d882f03a7d5c7edca02cfc7b2401fab3690dbe75ab7858db06908e64b28613da7257e737f39793da8e713ba0643b92e9bb3252be7f8fe", .msg = "313233343030", .sig = "30440220555555550000000055555555555555553ef7a8e48d07df81a693439654210c700220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70", .result = .valid },
        .{ .key = "04cf04ea77e9622523d894b93ff52dc3027b31959503b6fa3890e5e04263f922f1e8528fb7c006b3983c8b8400e57b4ed71740c2f3975438821199bedeaecab2e9", .msg = "313233343030", .sig = "30450220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70022100aaaaaaaa00000000aaaaaaaaaaaaaaaa7def51c91a0fbf034d26872ca84218e1", .result = .valid },
        .{ .key = "04db7a2c8a1ab573e5929dc24077b508d7e683d49227996bda3e9f78dbeff773504f417f3bc9a88075c2e0aadd5a13311730cf7cc76a82f11a36eaf08a6c99a206", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100e91e1ba60fdedb76a46bcb51dc0b8b4b7e019f0a28721885fa5d3a8196623397", .result = .valid },
        .{ .key = "04dead11c7a5b396862f21974dc4752fadeff994efe9bbd05ab413765ea80b6e1f1de3f0640e8ac6edcf89cff53c40e265bb94078a343736df07aa0318fc7fe1ff", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100fdea5843ffeb73af94313ba4831b53fe24f799e525b1e8e8c87b59b95b430ad9", .result = .valid },
        .{ .key = "04d0bc472e0d7c81ebaed3a6ef96c18613bb1fea6f994326fbe80e00dfde67c7e9986c723ea4843d48389b946f64ad56c83ad70ff17ba85335667d1bb9fa619efd", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022003ffcabf2f1b4d2a65190db1680d62bb994e41c5251cd73b3c3dfc5e5bafc035", .result = .valid },
        .{ .key = "04a0a44ca947d66a2acb736008b9c08d1ab2ad03776e02640f78495d458dd51c326337fe5cf8c4604b1f1c409dc2d872d4294a4762420df43a30a2392e40426add", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02204dfbc401f971cd304b33dfdb17d0fed0fe4c1a88ae648e0d2847f74977534989", .result = .valid },
        .{ .key = "04c9c2115290d008b45fb65fad0f602389298c25420b775019d42b62c3ce8a96b73877d25a8080dc02d987ca730f0405c2c9dbefac46f9e601cc3f06e9713973fd", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100bc4024761cd2ffd43dfdb17d0fed112b988977055cd3a8e54971eba9cda5ca71", .result = .valid },
        .{ .key = "045eca1ef4c287dddc66b8bccf1b88e8a24c0018962f3c5e7efa83bc1a5ff6033e5e79c4cb2c245b8c45abdce8a8e4da758d92a607c32cd407ecaef22f1c934a71", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0220788048ed39a5ffa77bfb62fa1fda2257742bf35d128fb3459f2a0c909ee86f91", .result = .valid },
        .{ .key = "045caaa030e7fdf0e4936bc7ab5a96353e0a01e4130c3f8bf22d473e317029a47adeb6adc462f7058f2a20d371e9702254e9b201642005b3ceda926b42b178bef9", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0220476d9131fd381bd917d0fed112bc9e0a5924b5ed5b11167edd8b23582b3cb15e", .result = .valid },
        .{ .key = "04c2fd20bac06e555bb8ac0ce69eb1ea20f83a1fc3501c8a66469b1a31f619b0986237050779f52b615bd7b8d76a25fc95ca2ed32525c75f27ffc87ac397e6cbaf", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0221008374253e3e21bd154448d0a8f640fe46fafa8b19ce78d538f6cc0a19662d3601", .result = .valid },
        .{ .key = "043fd6a1ca7f77fb3b0bbe726c372010068426e11ea6ae78ce17bedae4bba86ced03ce5516406bf8cfaab8745eac1cd69018ad6f50b5461872ddfc56e0db3c8ff4", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0220357cfd3be4d01d413c5b9ede36cba5452c11ee7fe14879e749ae6a2d897a52d6", .result = .valid },
        .{ .key = "049cb8e51e27a5ae3b624a60d6dc32734e4989db20e9bca3ede1edf7b086911114b4c104ab3c677e4b36d6556e8ad5f523410a19f2e277aa895fc57322b4427544", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022029798c5c0ee287d4a5e8e6b799fd86b8df5225298e6ffc807cd2f2bc27a0a6d8", .result = .valid },
        .{ .key = "04a3e52c156dcaf10502620b7955bc2b40bc78ef3d569e1223c262512d8f49602a4a2039f31c1097024ad3cc86e57321de032355463486164cf192944977df147f", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02200b70f22c781092452dca1a5711fa3a5a1f72add1bf52c2ff7cae4820b30078dd", .result = .valid },
        .{ .key = "04f19b78928720d5bee8e670fb90010fb15c37bf91b58a5157c3f3c059b2655e88cf701ec962fb4a11dcf273f5dc357e58468560c7cfeb942d074abd4329260509", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022016e1e458f021248a5b9434ae23f474b43ee55ba37ea585fef95c90416600f1ba", .result = .valid },
        .{ .key = "0483a744459ecdfb01a5cf52b27a05bb7337482d242f235d7b4cb89345545c90a8c05d49337b9649813287de9ffe90355fd905df5f3c32945828121f37cc50de6e", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02202252d6856831b6cf895e4f0535eeaf0e5e5809753df848fe760ad86219016a97", .result = .valid },
        .{ .key = "04dd13c6b34c56982ddae124f039dfd23f4b19bbe88cee8e528ae51e5d6f3a21d7bfad4c2e6f263fe5eb59ca974d039fc0e4c3345692fb5320bdae4bd3b42a45ff", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02210081ffe55f178da695b28c86d8b406b15dab1a9e39661a3ae017fbe390ac0972c3", .result = .valid },
        .{ .key = "0467e6f659cdde869a2f65f094e94e5b4dfad636bbf95192feeed01b0f3deb7460a37e0a51f258b7aeb51dfe592f5cfd5685bbe58712c8d9233c62886437c38ba0", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02207fffffffaaaaaaaaffffffffffffffffe9a2538f37b28a2c513dee40fecbb71a", .result = .valid },
        .{ .key = "042eb6412505aec05c6545f029932087e490d05511e8ec1f599617bb367f9ecaaf805f51efcc4803403f9b1ae0124890f06a43fedcddb31830f6669af292895cb0", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100b62f26b5f2a2b26f6de86d42ad8a13da3ab3cccd0459b201de009e526adf21f2", .result = .valid },
        .{ .key = "0484db645868eab35e3a9fd80e056e2e855435e3a6b68d75a50a854625fe0d7f356d2589ac655edc9a11ef3e075eddda9abf92e72171570ef7bf43a2ee39338cfe", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100bb1d9ac949dd748cd02bbbe749bd351cd57b38bb61403d700686aa7b4c90851e", .result = .valid },
        .{ .key = "0491b9e47c56278662d75c0983b22ca8ea6aa5059b7a2ff7637eb2975e386ad66349aa8ff283d0f77c18d6d11dc062165fd13c3c0310679c1408302a16854ecfbd", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022066755a00638cdaec1c732513ca0234ece52545dac11f816e818f725b4f60aaf2", .result = .valid },
        .{ .key = "04f3ec2f13caf04d0192b47fb4c5311fb6d4dc6b0a9e802e5327f7ec5ee8e4834df97e3e468b7d0db867d6ecfe81e2b0f9531df87efdb47c1338ac321fefe5a432", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022055a00c9fcdaebb6032513ca0234ecfffe98ebe492fdf02e48ca48e982beb3669", .result = .valid },
        .{ .key = "04d92b200aefcab6ac7dafd9acaf2fa10b3180235b8f46b4503e4693c670fccc885ef2f3aebf5b317475336256768f7c19efb7352d27e4cccadc85b6b8ab922c72", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100ab40193f9b5d76c064a27940469d9fffd31d7c925fbe05c919491d3057d66cd2", .result = .valid },
        .{ .key = "040a88361eb92ecca2625b38e5f98bbabb96bf179b3d76fc48140a3bcd881523cde6bdf56033f84a5054035597375d90866aa2c96b86a41ccf6edebf47298ad489", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100ca0234ebb5fdcb13ca0234ecffffffffcb0dadbbc7f549f8a26b4408d0dc8600", .result = .valid },
        .{ .key = "04d0fb17ccd8fafe827e0c1afc5d8d80366e2b20e7f14a563a2ba50469d84375e868612569d39e2bb9f554355564646de99ac602cc6349cf8c1e236a7de7637d93", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100bfffffff3ea3677e082b9310572620ae19933a9e65b285598711c77298815ad3", .result = .valid },
        .{ .key = "04836f33bbc1dc0d3d3abbcef0d91f11e2ac4181076c9af0a22b1e4309d3edb2769ab443ff6f901e30c773867582997c2bec2b0cb8120d760236f3a95bbe881f75", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0220266666663bbbbbbbe6666666666666665b37902e023fab7c8f055d86e5cc41f4", .result = .valid },
        .{ .key = "0492f99fbe973ed4a299719baee4b432741237034dec8d72ba5103cb33e55feeb8033dd0e91134c734174889f3ebcf1b7a1ac05767289280ee7a794cebd6e69697", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100bfffffff36db6db7a492492492492492146c573f4c6dfc8d08a443e258970b09", .result = .valid },
        .{ .key = "04d35ba58da30197d378e618ec0fa7e2e2d12cffd73ebbb2049d130bba434af09eff83986e6875e41ea432b7585a49b3a6c77cbb3c47919f8e82874c794635c1d2", .msg = "313233343030", .sig = "304502207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd022100bfffffff2aaaaaab7fffffffffffffffc815d0e60b3e596ecb1ad3a27cfd49c4", .result = .valid },
        .{ .key = "048651ce490f1b46d73f3ff475149be29136697334a519d7ddab0725c8d0793224e11c65bd8ca92dc8bc9ae82911f0b52751ce21dd9003ae60900bd825f590cc28", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02207fffffff55555555ffffffffffffffffd344a71e6f651458a27bdc81fd976e37", .result = .valid },
        .{ .key = "046d8e1b12c831a0da8795650ff95f101ed921d9e2f72b15b1cdaca9826b9cfc6def6d63e2bc5c089570394a4bc9f892d5e6c7a6a637b20469a58c106ad486bf37", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02203fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192aa", .result = .valid },
        .{ .key = "040ae580bae933b4ef2997cbdbb0922328ca9a410f627a0f7dff24cb4d920e15428911e7f8cc365a8a88eb81421a361ccc2b99e309d8dcd9a98ba83c3949d893e3", .msg = "313233343030", .sig = "304402207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd02205d8ecd64a4eeba466815ddf3a4de9a8e6abd9c5db0a01eb80343553da648428f", .result = .valid },
        .{ .key = "045b812fd521aafa69835a849cce6fbdeb6983b442d2444fe70e134c027fc46963838a40f2a36092e9004e92d8d940cf5638550ce672ce8b8d4e15eba5499249e9", .msg = "313233343030", .sig = "304502206f2347cab7dd76858fe0555ac3bc99048c4aacafdfb6bcbe05ea6c42c4934569022100bb726660235793aa9957a61e76e00c2c435109cf9a15dd624d53f4301047856b", .result = .valid },
        .{ .key = "045b812fd521aafa69835a849cce6fbdeb6983b442d2444fe70e134c027fc469637c75bf0c5c9f6d17ffb16d2726bf30a9c7aaf31a8d317472b1ea145ab66db616", .msg = "313233343030", .sig = "304502206f2347cab7dd76858fe0555ac3bc99048c4aacafdfb6bcbe05ea6c42c4934569022100bb726660235793aa9957a61e76e00c2c435109cf9a15dd624d53f4301047856b", .result = .invalid },
        .{ .key = "046adda82b90261b0f319faa0d878665a6b6da497f09c903176222c34acfef72a647e6f50dcc40ad5d9b59f7602bb222fad71a41bf5e1f9df4959a364c62e488d9", .msg = "313233343030", .sig = "30250201010220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70", .result = .invalid },
        .{ .key = "042fca0d0a47914de77ed56e7eccc3276a601120c6df0069c825c8f6a01c9f382065f3450a1d17c6b24989a39beb1c7decfca8384fbdc294418e5d807b3c6ed7de", .msg = "313233343030", .sig = "3045022101000000000000000000000000000000000000000000000000000000000000000002203333333300000000333333333333333325c7cbbc549e52e763f1f55a327a3aa9", .result = .invalid },
        .{ .key = "04dd86d3b5f4a13e8511083b78002081c53ff467f11ebd98a51a633db76665d25045d5c8200c89f2fa10d849349226d21d8dfaed6ff8d5cb3e1b7e17474ebc18f7", .msg = "313233343030", .sig = "30440220555555550000000055555555555555553ef7a8e48d07df81a693439654210c7002203333333300000000333333333333333325c7cbbc549e52e763f1f55a327a3aa9", .result = .invalid },
        .{ .key = "044fea55b32cb32aca0c12c4cd0abfb4e64b0f5a516e578c016591a93f5a0fbcc5d7d3fd10b2be668c547b212f6bb14c88f0fecd38a8a4b2c785ed3be62ce4b280", .msg = "313233343030", .sig = "304402207cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc476699780220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70", .result = .valid },
        .{ .key = "04c6a771527024227792170a6f8eee735bf32b7f98af669ead299802e32d7c3107bc3b4b5e65ab887bbd343572b3e5619261fe3a073e2ffd78412f726867db589e", .msg = "313233343030", .sig = "304502207cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978022100b6db6db6249249254924924924924924625bd7a09bec4ca81bcdd9f8fd6b63cc", .result = .valid },
        .{ .key = "04851c2bbad08e54ec7a9af99f49f03644d6ec6d59b207fec98de85a7d15b956efcee9960283045075684b410be8d0f7494b91aa2379f60727319f10ddeb0fe9d6", .msg = "313233343030", .sig = "304502207cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978022100cccccccc00000000cccccccccccccccc971f2ef152794b9d8fc7d568c9e8eaa7", .result = .valid },
        .{ .key = "04f6417c8a670584e388676949e53da7fc55911ff68318d1bf3061205acb19c48f8f2b743df34ad0f72674acb7505929784779cd9ac916c3669ead43026ab6d43f", .msg = "313233343030", .sig = "304402207cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc4766997802203333333300000000333333333333333325c7cbbc549e52e763f1f55a327a3aaa", .result = .valid },
        .{ .key = "04501421277be45a5eefec6c639930d636032565af420cf3373f557faa7f8a06438673d6cb6076e1cfcdc7dfe7384c8e5cac08d74501f2ae6e89cad195d0aa1371", .msg = "313233343030", .sig = "304402207cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978022049249248db6db6dbb6db6db6db6db6db5a8b230d0b2b51dcd7ebf0c9fef7c185", .result = .valid },
        .{ .key = "040d935bf9ffc115a527735f729ca8a4ca23ee01a4894adf0e3415ac84e808bb343195a3762fea29ed38912bd9ea6c4fde70c3050893a4375850ce61d82eba33c5", .msg = "313233343030", .sig = "304402207cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978022016a4502e2781e11ac82cbc9d1edd8c981584d13e18411e2f6e0478c34416e3bb", .result = .valid },
        .{ .key = "045e59f50708646be8a589355014308e60b668fb670196206c41e748e64e4dca215de37fee5c97bcaf7144d5b459982f52eeeafbdf03aacbafef38e213624a01de", .msg = "313233343030", .sig = "304402206b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2960220555555550000000055555555555555553ef7a8e48d07df81a693439654210c70", .result = .valid },
        .{ .key = "04169fb797325843faff2f7a5b5445da9e2fd6226f7ef90ef0bfe924104b02db8e7bbb8de662c7b9b1cf9b22f7a2e582bd46d581d68878efb2b861b131d8a1d667", .msg = "313233343030", .sig = "304502206b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296022100b6db6db6249249254924924924924924625bd7a09bec4ca81bcdd9f8fd6b63cc", .result = .valid },
        .{ .key = "04271cd89c000143096b62d4e9e4ca885aef2f7023d18affdaf8b7b548981487540a1c6e954e32108435b55fa385b0f76481a609b9149ccb4b02b2ca47fe8e4da5", .msg = "313233343030", .sig = "304502206b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296022100cccccccc00000000cccccccccccccccc971f2ef152794b9d8fc7d568c9e8eaa7", .result = .valid },
        .{ .key = "043d0bc7ed8f09d2cb7ddb46ebc1ed799ab1563a9ab84bf524587a220afe499c12e22dc3b3c103824a4f378d96adb0a408abf19ce7d68aa6244f78cb216fa3f8df", .msg = "313233343030", .sig = "304402206b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c29602203333333300000000333333333333333325c7cbbc549e52e763f1f55a327a3aaa", .result = .valid },
        .{ .key = "04a6c885ade1a4c566f9bb010d066974abb281797fa701288c721bcbd23663a9b72e424b690957168d193a6096fc77a2b004a9c7d467e007e1f2058458f98af316", .msg = "313233343030", .sig = "304402206b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296022049249248db6db6dbb6db6db6db6db6db5a8b230d0b2b51dcd7ebf0c9fef7c185", .result = .valid },
        .{ .key = "048d3c2c2c3b765ba8289e6ac3812572a25bf75df62d87ab7330c3bdbad9ebfa5c4c6845442d66935b238578d43aec54f7caa1621d1af241d4632e0b780c423f5d", .msg = "313233343030", .sig = "304402206b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296022016a4502e2781e11ac82cbc9d1edd8c981584d13e18411e2f6e0478c34416e3bb", .result = .valid },
        .{ .key = "046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5", .msg = "313233343030", .sig = "3045022100bb5a52f42f9c9261ed4361f59422a1e30036e7c32b270c8807a419feca6050230220249249246db6db6ddb6db6db6db6db6dad4591868595a8ee6bf5f864ff7be0c2", .result = .invalid },
        .{ .key = "046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5", .msg = "313233343030", .sig = "3044022044a5ad0ad0636d9f12bc9e0a6bdd5e1cbcb012ea7bf091fcec15b0c43202d52e0220249249246db6db6ddb6db6db6db6db6dad4591868595a8ee6bf5f864ff7be0c2", .result = .invalid },
        .{ .key = "046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296b01cbd1c01e58065711814b583f061e9d431cca994cea1313449bf97c840ae0a", .msg = "313233343030", .sig = "3045022100bb5a52f42f9c9261ed4361f59422a1e30036e7c32b270c8807a419feca6050230220249249246db6db6ddb6db6db6db6db6dad4591868595a8ee6bf5f864ff7be0c2", .result = .invalid },
        .{ .key = "046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296b01cbd1c01e58065711814b583f061e9d431cca994cea1313449bf97c840ae0a", .msg = "313233343030", .sig = "3044022044a5ad0ad0636d9f12bc9e0a6bdd5e1cbcb012ea7bf091fcec15b0c43202d52e0220249249246db6db6ddb6db6db6db6db6dad4591868595a8ee6bf5f864ff7be0c2", .result = .invalid },
        .{ .key = "0404aaec73635726f213fb8a9e64da3b8632e41495a944d0045b522eba7240fad587d9315798aaa3a5ba01775787ced05eaaf7b4e09fc81d6d1aa546e8365d525d", .msg = "", .sig = "3045022100b292a619339f6e567a305c951c0dcbcc42d16e47f219f9e98e76e09d8770b34a02200177e60492c5a8242f76f07bfe3661bde59ec2a17ce5bd2dab2abebdf89a62e2", .result = .valid },
        .{ .key = "0404aaec73635726f213fb8a9e64da3b8632e41495a944d0045b522eba7240fad587d9315798aaa3a5ba01775787ced05eaaf7b4e09fc81d6d1aa546e8365d525d", .msg = "4d7367", .sig = "30450220530bd6b0c9af2d69ba897f6b5fb59695cfbf33afe66dbadcf5b8d2a2a6538e23022100d85e489cb7a161fd55ededcedbf4cc0c0987e3e3f0f242cae934c72caa3f43e9", .result = .valid },
        .{ .key = "0404aaec73635726f213fb8a9e64da3b8632e41495a944d0045b522eba7240fad587d9315798aaa3a5ba01775787ced05eaaf7b4e09fc81d6d1aa546e8365d525d", .msg = "313233343030", .sig = "3046022100a8ea150cb80125d7381c4c1f1da8e9de2711f9917060406a73d7904519e51388022100f3ab9fa68bd47973a73b2d40480c2ba50c22c9d76ec217257288293285449b86", .result = .valid },
        .{ .key = "0404aaec73635726f213fb8a9e64da3b8632e41495a944d0045b522eba7240fad587d9315798aaa3a5ba01775787ced05eaaf7b4e09fc81d6d1aa546e8365d525d", .msg = "0000000000000000000000000000000000000000", .sig = "3045022100986e65933ef2ed4ee5aada139f52b70539aaf63f00a91f29c69178490d57fb7102203dafedfb8da6189d372308cbf1489bbbdabf0c0217d1c0ff0f701aaa7a694b9c", .result = .valid },
        .{ .key = "044f337ccfd67726a805e4f1600ae2849df3807eca117380239fbd816900000000ed9dea124cc8c396416411e988c30f427eb504af43a3146cd5df7ea60666d685", .msg = "4d657373616765", .sig = "3046022100d434e262a49eab7781e353a3565e482550dd0fd5defa013c7f29745eff3569f10221009b0c0a93f267fb6052fd8077be769c2b98953195d7bc10de844218305c6ba17a", .result = .valid },
        .{ .key = "044f337ccfd67726a805e4f1600ae2849df3807eca117380239fbd816900000000ed9dea124cc8c396416411e988c30f427eb504af43a3146cd5df7ea60666d685", .msg = "4d657373616765", .sig = "304402200fe774355c04d060f76d79fd7a772e421463489221bf0a33add0be9b1979110b0220500dcba1c69a8fbd43fa4f57f743ce124ca8b91a1f325f3fac6181175df55737", .result = .valid },
        .{ .key = "044f337ccfd67726a805e4f1600ae2849df3807eca117380239fbd816900000000ed9dea124cc8c396416411e988c30f427eb504af43a3146cd5df7ea60666d685", .msg = "4d657373616765", .sig = "3045022100bb40bf217bed3fb3950c7d39f03d36dc8e3b2cd79693f125bfd06595ee1135e30220541bf3532351ebb032710bdb6a1bf1bfc89a1e291ac692b3fa4780745bb55677", .result = .valid },
        .{ .key = "043cf03d614d8939cfd499a07873fac281618f06b8ff87e8015c3f49726500493584fa174d791c72bf2ce3880a8960dd2a7c7a1338a82f85a9e59cdbde80000000", .msg = "4d657373616765", .sig = "30440220664eb7ee6db84a34df3c86ea31389a5405badd5ca99231ff556d3e75a233e73a022059f3c752e52eca46137642490a51560ce0badc678754b8f72e51a2901426a1bd", .result = .valid },
        .{ .key = "043cf03d614d8939cfd499a07873fac281618f06b8ff87e8015c3f49726500493584fa174d791c72bf2ce3880a8960dd2a7c7a1338a82f85a9e59cdbde80000000", .msg = "4d657373616765", .sig = "304502204cd0429bbabd2827009d6fcd843d4ce39c3e42e2d1631fd001985a79d1fd8b430221009638bf12dd682f60be7ef1d0e0d98f08b7bca77a1a2b869ae466189d2acdabe3", .result = .valid },
        .{ .key = "043cf03d614d8939cfd499a07873fac281618f06b8ff87e8015c3f49726500493584fa174d791c72bf2ce3880a8960dd2a7c7a1338a82f85a9e59cdbde80000000", .msg = "4d657373616765", .sig = "3046022100e56c6ea2d1b017091c44d8b6cb62b9f460e3ce9aed5e5fd41e8added97c56c04022100a308ec31f281e955be20b457e463440b4fcf2b80258078207fc1378180f89b55", .result = .valid },
        .{ .key = "043cf03d614d8939cfd499a07873fac281618f06b8ff87e8015c3f4972650049357b05e8b186e38d41d31c77f5769f22d58385ecc857d07a561a6324217fffffff", .msg = "4d657373616765", .sig = "304402201158a08d291500b4cabed3346d891eee57c176356a2624fb011f8fbbf34668300220228a8c486a736006e082325b85290c5bc91f378b75d487dda46798c18f285519", .result = .valid },
        .{ .key = "043cf03d614d8939cfd499a07873fac281618f06b8ff87e8015c3f4972650049357b05e8b186e38d41d31c77f5769f22d58385ecc857d07a561a6324217fffffff", .msg = "4d657373616765", .sig = "3045022100b1db9289649f59410ea36b0c0fc8d6aa2687b29176939dd23e0dde56d309fa9d02203e1535e4280559015b0dbd987366dcf43a6d1af5c23c7d584e1c3f48a1251336", .result = .valid },
        .{ .key = "043cf03d614d8939cfd499a07873fac281618f06b8ff87e8015c3f4972650049357b05e8b186e38d41d31c77f5769f22d58385ecc857d07a561a6324217fffffff", .msg = "4d657373616765", .sig = "3046022100b7b16e762286cb96446aa8d4e6e7578b0a341a79f2dd1a220ac6f0ca4e24ed86022100ddc60a700a139b04661c547d07bbb0721780146df799ccf55e55234ecb8f12bc", .result = .valid },
        .{ .key = "042829c31faa2e400e344ed94bca3fcd0545956ebcfe8ad0f6dfa5ff8effffffffa01aafaf000e52585855afa7676ade284113099052df57e7eb3bd37ebeb9222e", .msg = "4d657373616765", .sig = "3045022100d82a7c2717261187c8e00d8df963ff35d796edad36bc6e6bd1c91c670d9105b402203dcabddaf8fcaa61f4603e7cbac0f3c0351ecd5988efb23f680d07debd139929", .result = .valid },
        .{ .key = "042829c31faa2e400e344ed94bca3fcd0545956ebcfe8ad0f6dfa5ff8effffffffa01aafaf000e52585855afa7676ade284113099052df57e7eb3bd37ebeb9222e", .msg = "4d657373616765", .sig = "304402205eb9c8845de68eb13d5befe719f462d77787802baff30ce96a5cba063254af7802202c026ae9be2e2a5e7ca0ff9bbd92fb6e44972186228ee9a62b87ddbe2ef66fb5", .result = .valid },
        .{ .key = "042829c31faa2e400e344ed94bca3fcd0545956ebcfe8ad0f6dfa5ff8effffffffa01aafaf000e52585855afa7676ade284113099052df57e7eb3bd37ebeb9222e", .msg = "4d657373616765", .sig = "304602210096843dd03c22abd2f3b782b170239f90f277921becc117d0404a8e4e36230c28022100f2be378f526f74a543f67165976de9ed9a31214eb4d7e6db19e1ede123dd991d", .result = .valid },
        .{ .key = "04fffffff948081e6a0458dd8f9e738f2665ff9059ad6aac0708318c4ca9a7a4f55a8abcba2dda8474311ee54149b973cae0c0fb89557ad0bf78e6529a1663bd73", .msg = "4d657373616765", .sig = "30440220766456dce1857c906f9996af729339464d27e9d98edc2d0e3b760297067421f60220402385ecadae0d8081dccaf5d19037ec4e55376eced699e93646bfbbf19d0b41", .result = .valid },
        .{ .key = "04fffffff948081e6a0458dd8f9e738f2665ff9059ad6aac0708318c4ca9a7a4f55a8abcba2dda8474311ee54149b973cae0c0fb89557ad0bf78e6529a1663bd73", .msg = "4d657373616765", .sig = "3046022100c605c4b2edeab20419e6518a11b2dbc2b97ed8b07cced0b19c34f777de7b9fd9022100edf0f612c5f46e03c719647bc8af1b29b2cde2eda700fb1cff5e159d47326dba", .result = .valid },
        .{ .key = "04fffffff948081e6a0458dd8f9e738f2665ff9059ad6aac0708318c4ca9a7a4f55a8abcba2dda8474311ee54149b973cae0c0fb89557ad0bf78e6529a1663bd73", .msg = "4d657373616765", .sig = "3046022100d48b68e6cabfe03cf6141c9ac54141f210e64485d9929ad7b732bfe3b7eb8a84022100feedae50c61bd00e19dc26f9b7e2265e4508c389109ad2f208f0772315b6c941", .result = .valid },
        .{ .key = "0400000003fa15f963949d5f03a6f5c7f86f9e0015eeb23aebbff1173937ba748e1099872070e8e87c555fa13659cca5d7fadcfcb0023ea889548ca48af2ba7e71", .msg = "4d657373616765", .sig = "3046022100b7c81457d4aeb6aa65957098569f0479710ad7f6595d5874c35a93d12a5dd4c7022100b7961a0b652878c2d568069a432ca18a1a9199f2ca574dad4b9e3a05c0a1cdb3", .result = .valid },
        .{ .key = "0400000003fa15f963949d5f03a6f5c7f86f9e0015eeb23aebbff1173937ba748e1099872070e8e87c555fa13659cca5d7fadcfcb0023ea889548ca48af2ba7e71", .msg = "4d657373616765", .sig = "304402206b01332ddb6edfa9a30a1321d5858e1ee3cf97e263e669f8de5e9652e76ff3f702205939545fced457309a6a04ace2bd0f70139c8f7d86b02cb1cc58f9e69e96cd5a", .result = .valid },
        .{ .key = "0400000003fa15f963949d5f03a6f5c7f86f9e0015eeb23aebbff1173937ba748e1099872070e8e87c555fa13659cca5d7fadcfcb0023ea889548ca48af2ba7e71", .msg = "4d657373616765", .sig = "3046022100efdb884720eaeadc349f9fc356b6c0344101cd2fd8436b7d0e6a4fb93f106361022100f24bee6ad5dc05f7613975473aadf3aacba9e77de7d69b6ce48cb60d8113385d", .result = .valid },
        .{ .key = "04bcbb2914c79f045eaa6ecbbc612816b3be5d2d6796707d8125e9f851c18af015000000001352bb4a0fa2ea4cceb9ab63dd684ade5a1127bcf300a698a7193bc2", .msg = "4d657373616765", .sig = "3044022031230428405560dcb88fb5a646836aea9b23a23dd973dcbe8014c87b8b20eb0702200f9344d6e812ce166646747694a41b0aaf97374e19f3c5fb8bd7ae3d9bd0beff", .result = .valid },
        .{ .key = "04bcbb2914c79f045eaa6ecbbc612816b3be5d2d6796707d8125e9f851c18af015000000001352bb4a0fa2ea4cceb9ab63dd684ade5a1127bcf300a698a7193bc2", .msg = "4d657373616765", .sig = "3046022100caa797da65b320ab0d5c470cda0b36b294359c7db9841d679174db34c4855743022100cf543a62f23e212745391aaf7505f345123d2685ee3b941d3de6d9b36242e5a0", .result = .valid },
        .{ .key = "04bcbb2914c79f045eaa6ecbbc612816b3be5d2d6796707d8125e9f851c18af015000000001352bb4a0fa2ea4cceb9ab63dd684ade5a1127bcf300a698a7193bc2", .msg = "4d657373616765", .sig = "304502207e5f0ab5d900d3d3d7867657e5d6d36519bc54084536e7d21c336ed8001859450221009450c07f201faec94b82dfb322e5ac676688294aad35aa72e727ff0b19b646aa", .result = .valid },
        .{ .key = "04bcbb2914c79f045eaa6ecbbc612816b3be5d2d6796707d8125e9f851c18af015fffffffeecad44b6f05d15b33146549c2297b522a5eed8430cff596758e6c43d", .msg = "4d657373616765", .sig = "3046022100d7d70c581ae9e3f66dc6a480bf037ae23f8a1e4a2136fe4b03aa69f0ca25b35602210089c460f8a5a5c2bbba962c8a3ee833a413e85658e62a59e2af41d9127cc47224", .result = .valid },
        .{ .key = "04bcbb2914c79f045eaa6ecbbc612816b3be5d2d6796707d8125e9f851c18af015fffffffeecad44b6f05d15b33146549c2297b522a5eed8430cff596758e6c43d", .msg = "4d657373616765", .sig = "30440220341c1b9ff3c83dd5e0dfa0bf68bcdf4bb7aa20c625975e5eeee34bb396266b34022072b69f061b750fd5121b22b11366fad549c634e77765a017902a67099e0a4469", .result = .valid },
        .{ .key = "04bcbb2914c79f045eaa6ecbbc612816b3be5d2d6796707d8125e9f851c18af015fffffffeecad44b6f05d15b33146549c2297b522a5eed8430cff596758e6c43d", .msg = "4d657373616765", .sig = "3045022070bebe684cdcb5ca72a42f0d873879359bd1781a591809947628d313a3814f67022100aec03aca8f5587a4d535fa31027bbe9cc0e464b1c3577f4c2dcde6b2094798a9", .result = .valid },
    };
    for (vectors) |vector| {
        if (tvTry(vector)) {
            try std.testing.expect(vector.result == .valid or vector.result == .acceptable);
        } else |_| {
            try std.testing.expectEqual(vector.result, .invalid);
        }
    }
}

fn tvTry(vector: TestVector) !void {
    const Scheme = EcdsaP256Sha256;
    var key_sec1_: [Scheme.PublicKey.uncompressed_sec1_encoded_length]u8 = undefined;
    const key_sec1 = try fmt.hexToBytes(&key_sec1_, vector.key);
    const pk = try Scheme.PublicKey.fromSec1(key_sec1);
    var msg_: [20]u8 = undefined;
    const msg = try fmt.hexToBytes(&msg_, vector.msg);
    var sig_der_: [152]u8 = undefined;
    const sig_der = try fmt.hexToBytes(&sig_der_, vector.sig);
    const sig = try Scheme.Signature.fromDer(sig_der);
    try sig.verify(msg, pk);
}

test "Sec1 encoding/decoding" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Scheme = EcdsaP384Sha384;
    const kp = try Scheme.KeyPair.generate();
    const pk = kp.public_key;
    const pk_compressed_sec1 = pk.toCompressedSec1();
    const pk_recovered1 = try Scheme.PublicKey.fromSec1(&pk_compressed_sec1);
    try testing.expectEqualSlices(u8, &pk_recovered1.toCompressedSec1(), &pk_compressed_sec1);
    const pk_uncompressed_sec1 = pk.toUncompressedSec1();
    const pk_recovered2 = try Scheme.PublicKey.fromSec1(&pk_uncompressed_sec1);
    try testing.expectEqualSlices(u8, &pk_recovered2.toUncompressedSec1(), &pk_uncompressed_sec1);
}

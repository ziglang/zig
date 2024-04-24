const builtin = @import("builtin");
const std = @import("std");
const der = @import("der.zig");
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

pub const EcdsaP256 = Ecdsa(crypto.ecc.P256);
pub const EcdsaP384 = Ecdsa(crypto.ecc.P384);
pub const EcdsaSecp256 = Ecdsa(crypto.ecc.Secp256k1);

/// Elliptic Curve Digital Signature Algorithm (ECDSA).
pub fn Ecdsa(comptime Curve: type) type {
    return struct {
        /// For non-deterministic signatures.
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
            pub fn verifier(self: Signature, comptime Hash: type, public_key: PublicKey) (NonCanonicalError || EncodingError || IdentityElementError)!Verifier {
                return Verifier(Hash).init(self, public_key);
            }

            /// Verify the signature against a message and public key.
            /// Return IdentityElement or NonCanonical if the public key or signature are not in the expected range,
            /// or SignatureVerificationError if the signature is invalid for the given message and key.
            pub fn verify(self: Signature, comptime Hash: type, msg: []const u8, public_key: PublicKey) (IdentityElementError || NonCanonicalError || SignatureVerificationError)!void {
                var st = try Verifier(Hash).init(self, public_key);
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

            pub fn fromDer(bytes: []const u8) !Signature {
                var parser = der.Parser{ .bytes = bytes };
                const seq = try parser.expectSequence();

                const max_len = @sizeOf(Curve.scalar.CompressedScalar);
                const r = try parser.expectPrimitive(.integer);
                if (r.slice.len() > max_len) return error.InvalidScalar;
                const s = try parser.expectPrimitive(.integer);
                if (s.slice.len() > max_len) return error.InvalidScalar;

                if (parser.index != seq.slice.end) return error.InvalidSequence;
                if (parser.index != parser.bytes.len) return error.InvalidSequence;

                var res = std.mem.zeroInit(Signature, .{});
                @memcpy(res.r[res.r.len - parser.view(r).len ..], parser.view(r));
                @memcpy(res.s[res.r.len - parser.view(s).len ..], parser.view(s));

                return res;
            }
        };

        /// A Signer is used to incrementally compute a signature.
        /// It can be obtained from a `KeyPair`, using the `signer()` function.
        pub fn Signer(comptime Hash: type) type {
            return struct {
                h: Hash,
                secret_key: SecretKey,
                noise: ?[noise_length]u8,

                fn init(secret_key: SecretKey, noise: ?[noise_length]u8) !@This() {
                    return .{
                        .h = Hash.init(.{}),
                        .secret_key = secret_key,
                        .noise = noise,
                    };
                }

                /// Add new data to the message being signed.
                pub fn update(self: *@This(), data: []const u8) void {
                    self.h.update(data);
                }

                /// Compute a signature over the entire message.
                pub fn finalize(self: *@This()) (IdentityElementError || NonCanonicalError)!Signature {
                    const scalar_encoded_length = Curve.scalar.encoded_length;
                    const h_len = @max(Hash.digest_length, scalar_encoded_length);
                    var h: [h_len]u8 = [_]u8{0} ** h_len;
                    const h_slice = h[h_len - Hash.digest_length .. h_len];
                    self.h.final(h_slice);

                    std.debug.assert(h.len >= scalar_encoded_length);
                    const z = reduceToScalar(scalar_encoded_length, h[0..scalar_encoded_length].*);

                    const k = deterministicScalar(Hash, h_slice.*, self.secret_key.bytes, self.noise);

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
        }

        /// A Verifier is used to incrementally verify a signature.
        /// It can be obtained from a `Signature`, using the `verifier()` function.
        pub fn Verifier(comptime Hash: type) type {
            return struct {
                h: Hash,
                r: Curve.scalar.Scalar,
                s: Curve.scalar.Scalar,
                public_key: PublicKey,

                fn init(sig: Signature, public_key: PublicKey) (IdentityElementError || NonCanonicalError)!@This() {
                    const r = try Curve.scalar.Scalar.fromBytes(sig.r, .big);
                    const s = try Curve.scalar.Scalar.fromBytes(sig.s, .big);
                    if (r.isZero() or s.isZero()) return error.IdentityElement;

                    return .{
                        .h = Hash.init(.{}),
                        .r = r,
                        .s = s,
                        .public_key = public_key,
                    };
                }

                /// Add new content to the message to be verified.
                pub fn update(self: *@This(), data: []const u8) void {
                    self.h.update(data);
                }

                /// Verify that the signature is valid for the entire message.
                pub fn verify(self: *@This()) (IdentityElementError || NonCanonicalError || SignatureVerificationError)!void {
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
        }

        /// An ECDSA key pair.
        pub const KeyPair = struct {
            /// Length (in bytes) of a seed required to create a key pair.
            pub const seed_length = noise_length;

            /// Public part.
            public_key: PublicKey,
            /// Secret scalar.
            secret_key: SecretKey,

            /// Create a new key pair. The seed must be secret and indistinguishable from random.
            /// The seed can also be left to null in order to generate a random key pair.
            pub fn create(comptime Hash: type, seed: ?[seed_length]u8) IdentityElementError!KeyPair {
                var seed_ = seed;
                if (seed_ == null) {
                    var random_seed: [seed_length]u8 = undefined;
                    crypto.random.bytes(&random_seed);
                    seed_ = random_seed;
                }
                const h = [_]u8{0x00} ** Hash.digest_length;
                const k0 = [_]u8{0x01} ** SecretKey.encoded_length;
                const secret_key = deterministicScalar(Hash, h, k0, seed_).toBytes(.big);
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
            pub fn sign(key_pair: KeyPair, comptime Hash: type, msg: []const u8, noise: ?[noise_length]u8) (IdentityElementError || NonCanonicalError)!Signature {
                var st = try key_pair.signer(Hash, noise);
                st.update(msg);
                return st.finalize();
            }

            /// Create a Signer, that can be used for incremental signature verification.
            pub fn signer(key_pair: KeyPair, comptime Hash: type, noise: ?[noise_length]u8) !Signer(Hash) {
                return Signer(Hash).init(key_pair.secret_key, noise);
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
        fn deterministicScalar(
            comptime Hash: type,
            h: [Hash.digest_length]u8,
            secret_key: Curve.scalar.CompressedScalar,
            noise: ?[noise_length]u8,
        ) Curve.scalar.Scalar {
            const Prf = switch (Hash) {
                sha3.Shake128 => sha3.KMac128,
                sha3.Shake256 => sha3.KMac256,
                else => crypto.auth.hmac.Hmac(Hash),
            };

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

test "EcdsaP384 with Sha384" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Hash = std.crypto.hash.sha2.Sha384;
    const kp = try EcdsaP384.KeyPair.create(Hash, null);
    const msg = "test";

    var noise: [EcdsaP384.noise_length]u8 = undefined;
    crypto.random.bytes(&noise);
    const sig = try kp.sign(Hash, msg, noise);
    try sig.verify(Hash, msg, kp.public_key);

    const sig2 = try kp.sign(Hash, msg, null);
    try sig2.verify(Hash, msg, kp.public_key);
}

test "EcdsaSecp256 with Sha256" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Hash = std.crypto.hash.sha2.Sha256;
    const kp = try EcdsaSecp256.KeyPair.create(Hash, null);
    const msg = "test";

    var noise: [EcdsaSecp256.noise_length]u8 = undefined;
    crypto.random.bytes(&noise);
    const sig = try kp.sign(Hash, msg, noise);
    try sig.verify(Hash, msg, kp.public_key);

    const sig2 = try kp.sign(Hash, msg, null);
    try sig2.verify(Hash, msg, kp.public_key);
}

test "EcdsaP384 with Sha256" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Hash = crypto.hash.sha2.Sha256;
    const kp = try EcdsaP384.KeyPair.create(Hash, null);
    const msg = "test";

    var noise: [EcdsaP384.noise_length]u8 = undefined;
    crypto.random.bytes(&noise);
    const sig = try kp.sign(Hash, msg, noise);
    try sig.verify(Hash, msg, kp.public_key);

    const sig2 = try kp.sign(Hash, msg, null);
    try sig2.verify(Hash, msg, kp.public_key);
}

test "EcdsaP384 with Sha256 signature" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Scheme = EcdsaP384;
    const Hash = crypto.hash.sha2.Sha256;
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
    try sig_ans.verify(Hash, &msg, kp.public_key);

    const sig = try kp.sign(Hash, &msg, null);
    try sig.verify(Hash, &msg, kp.public_key);
}

const wycheproof = @import("./testdata/ecdsa_secp256r1_sha256_wycheproof.zig");
test "EcdsaP256 with Sha256 Project Wycheproof" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    for (wycheproof.test_groups) |g| {
        var key_sec1_: [EcdsaP256.PublicKey.uncompressed_sec1_encoded_length]u8 = undefined;
        const key_sec1 = try fmt.hexToBytes(&key_sec1_, g.key);
        const pk = try EcdsaP256.PublicKey.fromSec1(key_sec1);

        for (g.tests) |t| {
            if (tryWycheproof(pk, t)) {
                try std.testing.expect(t.result == .valid or t.result == .acceptable);
            } else |_| {
                try std.testing.expectEqual(t.result, .invalid);
            }
        }
    }
}

fn tryWycheproof(pk: EcdsaP256.PublicKey, t: wycheproof.Test) !void {
    const Hash = crypto.hash.sha2.Sha256;
    var msg_: [20]u8 = undefined;
    const msg = try fmt.hexToBytes(&msg_, t.msg);
    var sig_der_: [152]u8 = undefined;
    const sig_der = try fmt.hexToBytes(&sig_der_, t.sig);
    const sig = try EcdsaP256.Signature.fromDer(sig_der);
    try sig.verify(Hash, msg, pk);
}

test "EcdsaP384 with Sha384 sec1 encoding/decoding" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Hash = std.crypto.hash.sha2.Sha384;
    const kp = try EcdsaP384.KeyPair.create(Hash, null);
    const pk = kp.public_key;
    const pk_compressed_sec1 = pk.toCompressedSec1();
    const pk_recovered1 = try EcdsaP384.PublicKey.fromSec1(&pk_compressed_sec1);
    try testing.expectEqualSlices(u8, &pk_recovered1.toCompressedSec1(), &pk_compressed_sec1);
    const pk_uncompressed_sec1 = pk.toUncompressedSec1();
    const pk_recovered2 = try EcdsaP384.PublicKey.fromSec1(&pk_uncompressed_sec1);
    try testing.expectEqualSlices(u8, &pk_recovered2.toUncompressedSec1(), &pk_uncompressed_sec1);
}

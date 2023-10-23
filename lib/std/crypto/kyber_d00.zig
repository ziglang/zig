//! Implementation of the IND-CCA2 post-quantum secure key encapsulation
//! mechanism (KEM) CRYSTALS-Kyber, as submitted to the third round of the NIST
//! Post-Quantum Cryptography (v3.02/"draft00"), and selected for standardisation.
//!
//! Kyber will likely change before final standardisation.
//!
//! The namespace suffix (currently `_d00`) refers to the version currently
//! implemented, in accordance with the draft. It may not be updated if new
//! versions of the draft only include editorial changes.
//!
//! The suffix will eventually be removed once Kyber is finalized.
//!
//! Quoting from the CFRG I-D:
//!
//! Kyber is not a Diffie-Hellman (DH) style non-interactive key
//! agreement, but instead, Kyber is a Key Encapsulation Method (KEM).
//! In essence, a KEM is a Public-Key Encryption (PKE) scheme where the
//! plaintext cannot be specified, but is generated as a random key as
//! part of the encryption. A KEM can be transformed into an unrestricted
//! PKE using HPKE (RFC9180). On its own, a KEM can be used as a key
//! agreement method in TLS.
//!
//! Kyber is an IND-CCA2 secure KEM. It is constructed by applying a
//! Fujisaki--Okamato style transformation on InnerPKE, which is the
//! underlying IND-CPA secure Public Key Encryption scheme. We cannot
//! use InnerPKE directly, as its ciphertexts are malleable.
//!
//! ```
//!                     F.O. transform
//!     InnerPKE   ---------------------->   Kyber
//!     IND-CPA                              IND-CCA2
//! ```
//!
//! Kyber is a lattice-based scheme.  More precisely, its security is
//! based on the learning-with-errors-and-rounding problem in module
//! lattices (MLWER).  The underlying polynomial ring R (defined in
//! Section 5) is chosen such that multiplication is very fast using the
//! number theoretic transform (NTT, see Section 5.1.3).
//!
//! An InnerPKE private key is a vector _s_ over R of length k which is
//! _small_ in a particular way.  Here k is a security parameter akin to
//! the size of a prime modulus.  For Kyber512, which targets AES-128's
//! security level, the value of k is 2.
//!
//! The public key consists of two values:
//!
//! * _A_ a uniformly sampled k by k matrix over R _and_
//!
//! * _t = A s + e_, where e is a suitably small masking vector.
//!
//! Distinguishing between such A s + e and a uniformly sampled t is the
//! module learning-with-errors (MLWE) problem.  If that is hard, then it
//! is also hard to recover the private key from the public key as that
//! would allow you to distinguish between those two.
//!
//! To save space in the public key, A is recomputed deterministically
//! from a seed _rho_.
//!
//! A ciphertext for a message m under this public key is a pair (c_1,
//! c_2) computed roughly as follows:
//!
//! c_1 = Compress(A^T r + e_1, d_u)
//! c_2 = Compress(t^T r + e_2 + Decompress(m, 1), d_v)
//!
//! where
//!
//! * e_1, e_2 and r are small blinds;
//!
//! * Compress(-, d) removes some information, leaving d bits per
//!   coefficient and Decompress is such that Compress after Decompress
//!   does nothing and
//!
//! * d_u, d_v are scheme parameters.
//!
//! Distinguishing such a ciphertext and uniformly sampled (c_1, c_2) is
//! an example of the full MLWER problem, see section 4.4 of [KyberV302].
//!
//! To decrypt the ciphertext, one computes
//!
//! m = Compress(Decompress(c_2, d_v) - s^T Decompress(c_1, d_u), 1).
//!
//! It it not straight-forward to see that this formula is correct.  In
//! fact, there is negligible but non-zero probability that a ciphertext
//! does not decrypt correctly given by the DFP column in Table 4.  This
//! failure probability can be computed by a careful automated analysis
//! of the probabilities involved, see kyber_failure.py of [SecEst].
//!
//! [KyberV302](https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf)
//! [I-D](https://github.com/bwesterb/draft-schwabe-cfrg-kyber)
//! [SecEst](https://github.com/pq-crystals/security-estimates)

// TODO
//
// - The bottleneck in Kyber are the various hash/xof calls:
//    - Optimize Zig's keccak implementation.
//    - Use SIMD to compute keccak in parallel.
// - Can we track bounds of coefficients using comptime types without
//   duplicating code?
// - Would be neater to have tests closer to the thing under test.
// - When generating a keypair, we have a copy of the inner public key with
//   its large matrix A in both the public key and the private key. In Go we
//   can just have a pointer in the private key to the public key, but
//   how do we do this elegantly in Zig?

const std = @import("std");
const builtin = @import("builtin");

const testing = std.testing;
const assert = std.debug.assert;
const crypto = std.crypto;
const math = std.math;
const mem = std.mem;
const RndGen = std.rand.DefaultPrng;
const sha3 = crypto.hash.sha3;

// Q is the parameter q ≡ 3329 = 2¹¹ + 2¹⁰ + 2⁸ + 1.
const Q: i16 = 3329;

// Montgomery R
const R: i32 = 1 << 16;

// Parameter n, degree of polynomials.
const N: usize = 256;

// Size of "small" vectors used in encryption blinds.
const eta2: u8 = 2;

const Params = struct {
    name: []const u8,

    // Width and height of the matrix A.
    k: u8,

    // Size of "small" vectors used in private key and encryption blinds.
    eta1: u8,

    // How many bits to retain of u, the private-key independent part
    // of the ciphertext.
    du: u8,

    // How many bits to retain of v, the private-key dependent part
    // of the ciphertext.
    dv: u8,
};

pub const Kyber512 = Kyber(.{
    .name = "Kyber512",
    .k = 2,
    .eta1 = 3,
    .du = 10,
    .dv = 4,
});

pub const Kyber768 = Kyber(.{
    .name = "Kyber768",
    .k = 3,
    .eta1 = 2,
    .du = 10,
    .dv = 4,
});

pub const Kyber1024 = Kyber(.{
    .name = "Kyber1024",
    .k = 4,
    .eta1 = 2,
    .du = 11,
    .dv = 5,
});

const modes = [_]type{ Kyber512, Kyber768, Kyber1024 };
const h_length: usize = 32;
const inner_seed_length: usize = 32;
const common_encaps_seed_length: usize = 32;
const common_shared_key_size: usize = 32;

fn Kyber(comptime p: Params) type {
    return struct {
        // Size of a ciphertext, in bytes.
        pub const ciphertext_length = Poly.compressedSize(p.du) * p.k + Poly.compressedSize(p.dv);

        const Self = @This();
        const V = Vec(p.k);
        const M = Mat(p.k);

        /// Length (in bytes) of a shared secret.
        pub const shared_length = common_shared_key_size;
        /// Length (in bytes) of a seed for deterministic encapsulation.
        pub const encaps_seed_length = common_encaps_seed_length;
        /// Length (in bytes) of a seed for key generation.
        pub const seed_length: usize = inner_seed_length + shared_length;
        /// Algorithm name.
        pub const name = p.name;

        /// A shared secret, and an encapsulated (encrypted) representation of it.
        pub const EncapsulatedSecret = struct {
            shared_secret: [shared_length]u8,
            ciphertext: [ciphertext_length]u8,
        };

        /// A Kyber public key.
        pub const PublicKey = struct {
            pk: InnerPk,

            // Cached
            hpk: [h_length]u8, // H(pk)

            /// Size of a serialized representation of the key, in bytes.
            pub const bytes_length = InnerPk.bytes_length;

            /// Generates a shared secret, and encapsulates it for the public key.
            /// If `seed` is `null`, a random seed is used. This is recommended.
            /// If `seed` is set, encapsulation is deterministic.
            pub fn encaps(pk: PublicKey, seed_: ?[encaps_seed_length]u8) EncapsulatedSecret {
                const seed = seed_ orelse seed: {
                    var random_seed: [encaps_seed_length]u8 = undefined;
                    crypto.random.bytes(&random_seed);
                    break :seed random_seed;
                };

                var m: [inner_plaintext_length]u8 = undefined;

                // m = H(seed)
                var h = sha3.Sha3_256.init(.{});
                h.update(&seed);
                h.final(&m);

                // (K', r) = G(m ‖ H(pk))
                var kr: [inner_plaintext_length + h_length]u8 = undefined;
                var g = sha3.Sha3_512.init(.{});
                g.update(&m);
                g.update(&pk.hpk);
                g.final(&kr);

                // c = innerEncrypy(pk, m, r)
                const ct = pk.pk.encrypt(&m, kr[32..64]);

                // Compute H(c) and put in second slot of kr, which will be (K', H(c)).
                h = sha3.Sha3_256.init(.{});
                h.update(&ct);
                h.final(kr[32..64]);

                // K = KDF(K' ‖ H(c))
                var kdf = sha3.Shake256.init(.{});
                kdf.update(&kr);
                var ss: [shared_length]u8 = undefined;
                kdf.squeeze(&ss);

                return EncapsulatedSecret{
                    .shared_secret = ss,
                    .ciphertext = ct,
                };
            }

            /// Serializes the key into a byte array.
            pub fn toBytes(pk: PublicKey) [bytes_length]u8 {
                return pk.pk.toBytes();
            }

            /// Deserializes the key from a byte array.
            pub fn fromBytes(buf: *const [bytes_length]u8) !PublicKey {
                var ret: PublicKey = undefined;
                ret.pk = InnerPk.fromBytes(buf[0..InnerPk.bytes_length]);

                var h = sha3.Sha3_256.init(.{});
                h.update(buf);
                h.final(&ret.hpk);
                return ret;
            }
        };

        /// A Kyber secret key.
        pub const SecretKey = struct {
            sk: InnerSk,
            pk: InnerPk,
            hpk: [h_length]u8, // H(pk)
            z: [shared_length]u8,

            /// Size of a serialized representation of the key, in bytes.
            pub const bytes_length: usize =
                InnerSk.bytes_length + InnerPk.bytes_length + h_length + shared_length;

            /// Decapsulates the shared secret within ct using the private key.
            pub fn decaps(sk: SecretKey, ct: *const [ciphertext_length]u8) ![shared_length]u8 {
                // m' = innerDec(ct)
                const m2 = sk.sk.decrypt(ct);

                // (K'', r') = G(m' ‖ H(pk))
                var kr2: [64]u8 = undefined;
                var g = sha3.Sha3_512.init(.{});
                g.update(&m2);
                g.update(&sk.hpk);
                g.final(&kr2);

                // ct' = innerEnc(pk, m', r')
                const ct2 = sk.pk.encrypt(&m2, kr2[32..64]);

                // Compute H(ct) and put in the second slot of kr2 which will be (K'', H(ct)).
                var h = sha3.Sha3_256.init(.{});
                h.update(ct);
                h.final(kr2[32..64]);

                // Replace K'' by z in the first slot of kr2 if ct ≠ ct'.
                cmov(32, kr2[0..32], sk.z, ctneq(ciphertext_length, ct.*, ct2));

                // K = KDF(K''/z, H(c))
                var kdf = sha3.Shake256.init(.{});
                var ss: [shared_length]u8 = undefined;
                kdf.update(&kr2);
                kdf.squeeze(&ss);
                return ss;
            }

            /// Serializes the key into a byte array.
            pub fn toBytes(sk: SecretKey) [bytes_length]u8 {
                return sk.sk.toBytes() ++ sk.pk.toBytes() ++ sk.hpk ++ sk.z;
            }

            /// Deserializes the key from a byte array.
            pub fn fromBytes(buf: *const [bytes_length]u8) !SecretKey {
                var ret: SecretKey = undefined;
                comptime var s: usize = 0;
                ret.sk = InnerSk.fromBytes(buf[s .. s + InnerSk.bytes_length]);
                s += InnerSk.bytes_length;
                ret.pk = InnerPk.fromBytes(buf[s .. s + InnerPk.bytes_length]);
                s += InnerPk.bytes_length;
                ret.hpk = buf[s..][0..h_length].*;
                s += h_length;
                ret.z = buf[s..][0..shared_length].*;
                return ret;
            }
        };

        /// A Kyber key pair.
        pub const KeyPair = struct {
            secret_key: SecretKey,
            public_key: PublicKey,

            /// Create a new key pair.
            /// If seed is null, a random seed will be generated.
            /// If a seed is provided, the key pair will be determinsitic.
            pub fn create(seed_: ?[seed_length]u8) !KeyPair {
                const seed = seed_ orelse sk: {
                    var random_seed: [seed_length]u8 = undefined;
                    crypto.random.bytes(&random_seed);
                    break :sk random_seed;
                };
                var ret: KeyPair = undefined;
                ret.secret_key.z = seed[inner_seed_length..seed_length].*;

                // Generate inner key
                innerKeyFromSeed(
                    seed[0..inner_seed_length].*,
                    &ret.public_key.pk,
                    &ret.secret_key.sk,
                );
                ret.secret_key.pk = ret.public_key.pk;

                // Copy over z from seed.
                ret.secret_key.z = seed[inner_seed_length..seed_length].*;

                // Compute H(pk)
                var h = sha3.Sha3_256.init(.{});
                h.update(&ret.public_key.pk.toBytes());
                h.final(&ret.secret_key.hpk);
                ret.public_key.hpk = ret.secret_key.hpk;

                return ret;
            }
        };

        // Size of plaintexts of the in
        const inner_plaintext_length: usize = Poly.compressedSize(1);

        const InnerPk = struct {
            rho: [32]u8, // ρ, the seed for the matrix A
            th: V, // NTT(t), normalized

            // Cached values
            aT: M,

            const bytes_length = V.bytes_length + 32;

            fn encrypt(
                pk: InnerPk,
                pt: *const [inner_plaintext_length]u8,
                seed: *const [32]u8,
            ) [ciphertext_length]u8 {
                // Sample r, e₁ and e₂ appropriately
                const rh = V.noise(p.eta1, 0, seed).ntt().barrettReduce();
                const e1 = V.noise(eta2, p.k, seed);
                const e2 = Poly.noise(eta2, 2 * p.k, seed);

                // Next we compute u = Aᵀ r + e₁.  First Aᵀ.
                var u: V = undefined;
                for (0..p.k) |i| {
                    // Note that coefficients of r are bounded by q and those of Aᵀ
                    // are bounded by 4.5q and so their product is bounded by 2¹⁵q
                    // as required for multiplication.
                    u.ps[i] = pk.aT.vs[i].dotHat(rh);
                }

                // Aᵀ and r were not in Montgomery form, so the Montgomery
                // multiplications in the inner product added a factor R⁻¹ which
                // the InvNTT cancels out.
                u = u.barrettReduce().invNTT().add(e1).normalize();

                // Next, compute v = <t, r> + e₂ + Decompress_q(m, 1)
                const v = pk.th.dotHat(rh).barrettReduce().invNTT()
                    .add(Poly.decompress(1, pt)).add(e2).normalize();

                return u.compress(p.du) ++ v.compress(p.dv);
            }

            fn toBytes(pk: InnerPk) [bytes_length]u8 {
                return pk.th.toBytes() ++ pk.rho;
            }

            fn fromBytes(buf: *const [bytes_length]u8) InnerPk {
                var ret: InnerPk = undefined;
                ret.th = V.fromBytes(buf[0..V.bytes_length]).normalize();
                ret.rho = buf[V.bytes_length..bytes_length].*;
                ret.aT = M.uniform(ret.rho, true);
                return ret;
            }
        };

        // Private key of the inner PKE
        const InnerSk = struct {
            sh: V, // NTT(s), normalized
            const bytes_length = V.bytes_length;

            fn decrypt(sk: InnerSk, ct: *const [ciphertext_length]u8) [inner_plaintext_length]u8 {
                const u = V.decompress(p.du, ct[0..comptime V.compressedSize(p.du)]);
                const v = Poly.decompress(
                    p.dv,
                    ct[comptime V.compressedSize(p.du)..ciphertext_length],
                );

                // Compute m = v - <s, u>
                return v.sub(sk.sh.dotHat(u.ntt()).barrettReduce().invNTT())
                    .normalize().compress(1);
            }

            fn toBytes(sk: InnerSk) [bytes_length]u8 {
                return sk.sh.toBytes();
            }

            fn fromBytes(buf: *const [bytes_length]u8) InnerSk {
                var ret: InnerSk = undefined;
                ret.sh = V.fromBytes(buf).normalize();
                return ret;
            }
        };

        // Derives inner PKE keypair from given seed.
        fn innerKeyFromSeed(seed: [inner_seed_length]u8, pk: *InnerPk, sk: *InnerSk) void {
            var expanded_seed: [64]u8 = undefined;

            var h = sha3.Sha3_512.init(.{});
            h.update(&seed);
            h.final(&expanded_seed);
            pk.rho = expanded_seed[0..32].*;
            const sigma = expanded_seed[32..64];
            pk.aT = M.uniform(pk.rho, false); // Expand ρ to A; we'll transpose later on

            // Sample secret vector s.
            sk.sh = V.noise(p.eta1, 0, sigma).ntt().normalize();

            const eh = Vec(p.k).noise(p.eta1, p.k, sigma).ntt(); // sample blind e.
            var th: V = undefined;

            // Next, we compute t = A s + e.
            for (0..p.k) |i| {
                // Note that coefficients of s are bounded by q and those of A
                // are bounded by 4.5q and so their product is bounded by 2¹⁵q
                // as required for multiplication.
                // A and s were not in Montgomery form, so the Montgomery
                // multiplications in the inner product added a factor R⁻¹ which
                // we'll cancel out with toMont().  This will also ensure the
                // coefficients of th are bounded in absolute value by q.
                th.ps[i] = pk.aT.vs[i].dotHat(sk.sh).toMont();
            }

            pk.th = th.add(eh).normalize(); // bounded by 8q
            pk.aT = pk.aT.transpose();
        }
    };
}

// R mod q
const r_mod_q: i32 = @rem(@as(i32, R), Q);

// R² mod q
const r2_mod_q: i32 = @rem(r_mod_q * r_mod_q, Q);

// ζ is the degree 256 primitive root of unity used for the NTT.
const zeta: i16 = 17;

// (128)⁻¹ R². Used in inverse NTT.
const r2_over_128: i32 = @mod(invertMod(128, Q) * r2_mod_q, Q);

// zetas lists precomputed powers of the primitive root of unity in
// Montgomery representation used for the NTT:
//
//  zetas[i] = ζᵇʳᵛ⁽ⁱ⁾ R mod q
//
// where ζ = 17, brv(i) is the bitreversal of a 7-bit number and R=2¹⁶ mod q.
const zetas = computeZetas();

// invNTTReductions keeps track of which coefficients to apply Barrett
// reduction to in Poly.invNTT().
//
// Generated lazily: once a butterfly is computed which is about to
// overflow the i16, the largest coefficient is reduced.  If that is
// not enough, the other coefficient is reduced as well.
//
// This is actually optimal, as proven in https://eprint.iacr.org/2020/1377.pdf
// TODO generate comptime?
const inv_ntt_reductions = [_]i16{
    -1, // after layer 1
    -1, // after layer 2
    16,
    17,
    48,
    49,
    80,
    81,
    112,
    113,
    144,
    145,
    176,
    177,
    208,
    209,
    240, 241, -1, // after layer 3
    0,   1,   32,
    33,  34,  35,
    64,  65,  96,
    97,  98,  99,
    128, 129,
    160, 161, 162, 163, 192, 193, 224, 225, 226, 227, -1, // after layer 4
    2,   3,   66,  67,  68,  69,  70,  71,  130, 131, 194,
    195, 196, 197,
    198, 199, -1, // after layer 5
    4,   5,   6,
    7,   132, 133,
    134, 135, 136,
    137, 138, 139,
    140, 141,
    142, 143, -1, // after layer 6
    -1, //  after layer 7
};

test "invNTTReductions bounds" {
    // Checks whether the reductions proposed by invNTTReductions
    // don't overflow during invNTT().
    var xs = [_]i32{1} ** 256; // start at |x| ≤ q

    var r: usize = 0;
    var layer: math.Log2Int(usize) = 1;
    while (layer < 8) : (layer += 1) {
        const w = @as(usize, 1) << layer;
        var i: usize = 0;

        while (i + w < 256) {
            xs[i] = xs[i] + xs[i + w];
            try testing.expect(xs[i] <= 9); // we can't exceed 9q
            xs[i + w] = 1;
            i += 1;
            if (@mod(i, w) == 0) {
                i += w;
            }
        }

        while (true) {
            const j = inv_ntt_reductions[r];
            r += 1;
            if (j < 0) {
                break;
            }
            xs[@as(usize, @intCast(j))] = 1;
        }
    }
}

// Extended euclidean algorithm.
//
// For a, b finds x, y such that  x a + y b = gcd(a, b). Used to compute
// modular inverse.
fn eea(a: anytype, b: @TypeOf(a)) EeaResult(@TypeOf(a)) {
    if (a == 0) {
        return .{ .gcd = b, .x = 0, .y = 1 };
    }
    const r = eea(@rem(b, a), a);
    return .{ .gcd = r.gcd, .x = r.y - @divTrunc(b, a) * r.x, .y = r.x };
}

fn EeaResult(comptime T: type) type {
    return struct { gcd: T, x: T, y: T };
}

// Returns least common multiple of a and b.
fn lcm(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    const r = eea(a, b);
    return a * b / r.gcd;
}

// Invert modulo p.
fn invertMod(a: anytype, p: @TypeOf(a)) @TypeOf(a) {
    const r = eea(a, p);
    assert(r.gcd == 1);
    return r.x;
}

// Reduce mod q for testing.
fn modQ32(x: i32) i16 {
    var y = @as(i16, @intCast(@rem(x, @as(i32, Q))));
    if (y < 0) {
        y += Q;
    }
    return y;
}

// Given -2¹⁵ q ≤ x < 2¹⁵ q, returns -q < y < q with x 2⁻¹⁶ = y (mod q).
fn montReduce(x: i32) i16 {
    const qInv = comptime invertMod(@as(i32, Q), R);
    // This is Montgomery reduction with R=2¹⁶.
    //
    // Note gcd(2¹⁶, q) = 1 as q is prime.  Write q' := 62209 = q⁻¹ mod R.
    // First we compute
    //
    //	m := ((x mod R) q') mod R
    //         = x q' mod R
    //	   = int16(x q')
    //	   = int16(int32(x) * int32(q'))
    //
    // Note that x q' might be as big as 2³² and could overflow the int32
    // multiplication in the last line.  However for any int32s a and b,
    // we have int32(int64(a)*int64(b)) = int32(a*b) and so the result is ok.
    const m: i16 = @truncate(@as(i32, @truncate(x *% qInv)));

    // Note that x - m q is divisible by R; indeed modulo R we have
    //
    //  x - m q ≡ x - x q' q ≡ x - x q⁻¹ q ≡ x - x = 0.
    //
    // We return y := (x - m q) / R.  Note that y is indeed correct as
    // modulo q we have
    //
    //  y ≡ x R⁻¹ - m q R⁻¹ = x R⁻¹
    //
    // and as both 2¹⁵ q ≤ m q, x < 2¹⁵ q, we have
    // 2¹⁶ q ≤ x - m q < 2¹⁶ and so q ≤ (x - m q) / R < q as desired.
    const yR = x - @as(i32, m) * @as(i32, Q);
    return @bitCast(@as(u16, @truncate(@as(u32, @bitCast(yR)) >> 16)));
}

test "Test montReduce" {
    var rnd = RndGen.init(0);
    for (0..1000) |_| {
        const bound = comptime @as(i32, Q) * (1 << 15);
        const x = rnd.random().intRangeLessThan(i32, -bound, bound);
        const y = montReduce(x);
        try testing.expect(-Q < y and y < Q);
        try testing.expectEqual(modQ32(x), modQ32(@as(i32, y) * R));
    }
}

// Given any x, return x R mod q where R=2¹⁶.
fn feToMont(x: i16) i16 {
    // Note |1353 x| ≤ 1353 2¹⁵ ≤ 13318 q ≤ 2¹⁵ q and so we're within
    // the bounds of montReduce.
    return montReduce(@as(i32, x) * r2_mod_q);
}

test "Test feToMont" {
    var x: i32 = -(1 << 15);
    while (x < 1 << 15) : (x += 1) {
        const y = feToMont(@as(i16, @intCast(x)));
        try testing.expectEqual(modQ32(@as(i32, y)), modQ32(x * r_mod_q));
    }
}

// Given any x, compute 0 ≤ y ≤ q with x = y (mod q).
//
// Beware: we might have feBarrettReduce(x) = q ≠ 0 for some x.  In fact,
// this happens if and only if x = -nq for some positive integer n.
fn feBarrettReduce(x: i16) i16 {
    // This is standard Barrett reduction.
    //
    // For any x we have x mod q = x - ⌊x/q⌋ q.  We will use 20159/2²⁶ as
    // an approximation of 1/q. Note that  0 ≤ 20159/2²⁶ - 1/q ≤ 0.135/2²⁶
    // and so | x 20156/2²⁶ - x/q | ≤ 2⁻¹⁰ for |x| ≤ 2¹⁶.  For all x
    // not a multiple of q, the number x/q is further than 1/q from any integer
    // and so ⌊x 20156/2²⁶⌋ = ⌊x/q⌋.  If x is a multiple of q and x is positive,
    // then x 20156/2²⁶ is larger than x/q so ⌊x 20156/2²⁶⌋ = ⌊x/q⌋ as well.
    // Finally, if x is negative multiple of q, then ⌊x 20156/2²⁶⌋ = ⌊x/q⌋-1.
    // Thus
    //                        [ q        if x=-nq for pos. integer n
    //  x - ⌊x 20156/2²⁶⌋ q = [
    //                        [ x mod q  otherwise
    //
    // To actually compute this, note that
    //
    //  ⌊x 20156/2²⁶⌋ = (20159 x) >> 26.
    return x -% @as(i16, @intCast((@as(i32, x) * 20159) >> 26)) *% Q;
}

test "Test Barrett reduction" {
    var x: i32 = -(1 << 15);
    while (x < 1 << 15) : (x += 1) {
        var y1 = feBarrettReduce(@as(i16, @intCast(x)));
        const y2 = @mod(@as(i16, @intCast(x)), Q);
        if (x < 0 and @rem(-x, Q) == 0) {
            y1 -= Q;
        }
        try testing.expectEqual(y1, y2);
    }
}

// Returns x if x < q and x - q otherwise.  Assumes x ≥ -29439.
fn csubq(x: i16) i16 {
    var r = x;
    r -= Q;
    r += (r >> 15) & Q;
    return r;
}

test "Test csubq" {
    var x: i32 = -29439;
    while (x < 1 << 15) : (x += 1) {
        const y1 = csubq(@as(i16, @intCast(x)));
        var y2 = @as(i16, @intCast(x));
        if (@as(i16, @intCast(x)) >= Q) {
            y2 -= Q;
        }
        try testing.expectEqual(y1, y2);
    }
}

// Compute a^s mod p.
fn mpow(a: anytype, s: @TypeOf(a), p: @TypeOf(a)) @TypeOf(a) {
    var ret: @TypeOf(a) = 1;
    var s2 = s;
    var a2 = a;

    while (true) {
        if (s2 & 1 == 1) {
            ret = @mod(ret * a2, p);
        }
        s2 >>= 1;
        if (s2 == 0) {
            break;
        }
        a2 = @mod(a2 * a2, p);
    }
    return ret;
}

// Computes zetas table used by ntt and invNTT.
fn computeZetas() [128]i16 {
    @setEvalBranchQuota(10000);
    var ret: [128]i16 = undefined;
    for (&ret, 0..) |*r, i| {
        const t = @as(i16, @intCast(mpow(@as(i32, zeta), @bitReverse(@as(u7, @intCast(i))), Q)));
        r.* = csubq(feBarrettReduce(feToMont(t)));
    }
    return ret;
}

// An element of our base ring R which are polynomials over ℤ_q
// modulo the equation Xᴺ = -1, where q=3329 and N=256.
//
// This type is also used to store NTT-transformed polynomials,
// see Poly.NTT().
//
// Coefficients aren't always reduced.  See Normalize().
const Poly = struct {
    cs: [N]i16,

    const bytes_length = N / 2 * 3;
    const zero: Poly = .{ .cs = .{0} ** N };

    fn add(a: Poly, b: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = a.cs[i] + b.cs[i];
        }
        return ret;
    }

    fn sub(a: Poly, b: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = a.cs[i] - b.cs[i];
        }
        return ret;
    }

    // For testing, generates a random polynomial with for each
    // coefficient |x| ≤ q.
    fn randAbsLeqQ(rnd: anytype) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = rnd.random().intRangeAtMost(i16, -Q, Q);
        }
        return ret;
    }

    // For testing, generates a random normalized polynomial.
    fn randNormalized(rnd: anytype) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = rnd.random().intRangeLessThan(i16, 0, Q);
        }
        return ret;
    }

    // Executes a forward "NTT" on p.
    //
    // Assumes the coefficients are in absolute value ≤q.  The resulting
    // coefficients are in absolute value ≤7q.  If the input is in Montgomery
    // form, then the result is in Montgomery form and so (by linearity of the NTT)
    // if the input is in regular form, then the result is also in regular form.
    fn ntt(a: Poly) Poly {
        // Note that ℤ_q does not have a primitive 512ᵗʰ root of unity (as 512
        // does not divide into q-1) and so we cannot do a regular NTT.  ℤ_q
        // does have a primitive 256ᵗʰ root of unity, the smallest of which
        // is ζ := 17.
        //
        // Recall that our base ring R := ℤ_q[x] / (x²⁵⁶ + 1).  The polynomial
        // x²⁵⁶+1 will not split completely (as its roots would be 512ᵗʰ roots
        // of unity.)  However, it does split almost (using ζ¹²⁸ = -1):
        //
        // x²⁵⁶ + 1 = (x²)¹²⁸ - ζ¹²⁸
        //          = ((x²)⁶⁴ - ζ⁶⁴)((x²)⁶⁴ + ζ⁶⁴)
        //          = ((x²)³² - ζ³²)((x²)³² + ζ³²)((x²)³² - ζ⁹⁶)((x²)³² + ζ⁹⁶)
        //          ⋮
        //          = (x² - ζ)(x² + ζ)(x² - ζ⁶⁵)(x² + ζ⁶⁵) … (x² + ζ¹²⁷)
        //
        // Note that the powers of ζ that appear (from the second line down) are
        // in binary
        //
        // 0100000 1100000
        // 0010000 1010000 0110000 1110000
        // 0001000 1001000 0101000 1101000 0011000 1011000 0111000 1111000
        //         …
        //
        // That is: brv(2), brv(3), brv(4), …, where brv(x) denotes the 7-bit
        // bitreversal of x.  These powers of ζ are given by the Zetas array.
        //
        // The polynomials x² ± ζⁱ are irreducible and coprime, hence by
        // the Chinese Remainder Theorem we know
        //
        //  ℤ_q[x]/(x²⁵⁶+1) → ℤ_q[x]/(x²-ζ) x … x  ℤ_q[x]/(x²+ζ¹²⁷)
        //
        // given by a ↦ ( a mod x²-ζ, …, a mod x²+ζ¹²⁷ )
        // is an isomorphism, which is the "NTT".  It can be efficiently computed by
        //
        //
        //  a ↦ ( a mod (x²)⁶⁴ - ζ⁶⁴, a mod (x²)⁶⁴ + ζ⁶⁴ )
        //    ↦ ( a mod (x²)³² - ζ³², a mod (x²)³² + ζ³²,
        //        a mod (x²)⁹⁶ - ζ⁹⁶, a mod (x²)⁹⁶ + ζ⁹⁶ )
        //
        //      et cetera
        // If N was 8 then this can be pictured in the following diagram:
        //
        //  https://cnx.org/resources/17ee4dfe517a6adda05377b25a00bf6e6c93c334/File0026.png
        //
        // Each cross is a Cooley-Tukey butterfly: it's the map
        //
        //  (a, b) ↦ (a + ζb, a - ζb)
        //
        // for the appropriate power ζ for that column and row group.
        var p = a;
        var k: usize = 0; // index into zetas

        var l = N >> 1;
        while (l > 1) : (l >>= 1) {
            // On the nᵗʰ iteration of the l-loop, the absolute value of the
            // coefficients are bounded by nq.

            // offset effectively loops over the row groups in this column; it is
            // the first row in the row group.
            var offset: usize = 0;
            while (offset < N - l) : (offset += 2 * l) {
                k += 1;
                const z = @as(i32, zetas[k]);

                // j loops over each butterfly in the row group.
                for (offset..offset + l) |j| {
                    const t = montReduce(z * @as(i32, p.cs[j + l]));
                    p.cs[j + l] = p.cs[j] - t;
                    p.cs[j] += t;
                }
            }
        }

        return p;
    }

    // Executes an inverse "NTT" on p and multiply by the Montgomery factor R.
    //
    // Assumes the coefficients are in absolute value ≤q.  The resulting
    // coefficients are in absolute value ≤q.  If the input is in Montgomery
    // form, then the result is in Montgomery form and so (by linearity)
    // if the input is in regular form, then the result is also in regular form.
    fn invNTT(a: Poly) Poly {
        var k: usize = 127; // index into zetas
        var r: usize = 0; // index into invNTTReductions
        var p = a;

        // We basically do the oppposite of NTT, but postpone dividing by 2 in the
        // inverse of the Cooley-Tukey butterfly and accumulate that into a big
        // division by 2⁷ at the end.  See the comments in the ntt() function.

        var l: usize = 2;
        while (l < N) : (l <<= 1) {
            var offset: usize = 0;
            while (offset < N - l) : (offset += 2 * l) {
                // As we're inverting, we need powers of ζ⁻¹ (instead of ζ).
                // To be precise, we need ζᵇʳᵛ⁽ᵏ⁾⁻¹²⁸. However, as ζ⁻¹²⁸ = -1,
                // we can use the existing zetas table instead of
                // keeping a separate invZetas table as in Dilithium.

                const minZeta = @as(i32, zetas[k]);
                k -= 1;

                for (offset..offset + l) |j| {
                    // Gentleman-Sande butterfly: (a, b) ↦ (a + b, ζ(a-b))
                    const t = p.cs[j + l] - p.cs[j];
                    p.cs[j] += p.cs[j + l];
                    p.cs[j + l] = montReduce(minZeta * @as(i32, t));

                    // Note that if we had |a| < αq and |b| < βq before the
                    // butterfly, then now we have |a| < (α+β)q and |b| < q.
                }
            }

            // We let the invNTTReductions instruct us which coefficients to
            // Barrett reduce.
            while (true) {
                const i = inv_ntt_reductions[r];
                r += 1;
                if (i < 0) {
                    break;
                }
                p.cs[@as(usize, @intCast(i))] = feBarrettReduce(p.cs[@as(usize, @intCast(i))]);
            }
        }

        for (0..N) |j| {
            // Note 1441 = (128)⁻¹ R².  The coefficients are bounded by 9q, so
            // as 1441 * 9 ≈ 2¹⁴ < 2¹⁵, we're within the required bounds
            // for montReduce().
            p.cs[j] = montReduce(r2_over_128 * @as(i32, p.cs[j]));
        }

        return p;
    }

    // Normalizes coefficients.
    //
    // Ensures each coefficient is in {0, …, q-1}.
    fn normalize(a: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = csubq(feBarrettReduce(a.cs[i]));
        }
        return ret;
    }

    // Put p in Montgomery form.
    fn toMont(a: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = feToMont(a.cs[i]);
        }
        return ret;
    }

    // Barret reduce coefficients.
    //
    // Beware, this does not fully normalize coefficients.
    fn barrettReduce(a: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = feBarrettReduce(a.cs[i]);
        }
        return ret;
    }

    fn compressedSize(comptime d: u8) usize {
        return @divTrunc(N * d, 8);
    }

    // Returns packed Compress_q(p, d).
    //
    // Assumes p is normalized.
    fn compress(p: Poly, comptime d: u8) [compressedSize(d)]u8 {
        @setEvalBranchQuota(10000);
        const q_over_2: u32 = comptime @divTrunc(Q, 2); // (q-1)/2
        const two_d_min_1: u32 = comptime (1 << d) - 1; // 2ᵈ-1
        var in_off: usize = 0;
        var out_off: usize = 0;

        const batch_size: usize = comptime lcm(@as(i16, d), 8);
        const in_batch_size: usize = comptime batch_size / d;
        const out_batch_size: usize = comptime batch_size / 8;

        const out_length: usize = comptime @divTrunc(N * d, 8);
        comptime assert(out_length * 8 == d * N);
        var out = [_]u8{0} ** out_length;

        while (in_off < N) {
            // First we compress into in.
            var in: [in_batch_size]u16 = undefined;
            inline for (0..in_batch_size) |i| {
                // Compress_q(x, d) = ⌈(2ᵈ/q)x⌋ mod⁺ 2ᵈ
                //                  = ⌊(2ᵈ/q)x+½⌋ mod⁺ 2ᵈ
                //                  = ⌊((x << d) + q/2) / q⌋ mod⁺ 2ᵈ
                //                  = DIV((x << d) + q/2, q) & ((1<<d) - 1)
                const t = @as(u32, @intCast(p.cs[in_off + i])) << d;
                in[i] = @as(u16, @intCast(@divFloor(t + q_over_2, Q) & two_d_min_1));
            }

            // Now we pack the d-bit integers from `in' into out as bytes.
            comptime var in_shift: usize = 0;
            comptime var j: usize = 0;
            comptime var i: usize = 0;
            inline while (i < in_batch_size) : (j += 1) {
                comptime var todo: usize = 8;
                inline while (todo > 0) {
                    const out_shift = comptime 8 - todo;
                    out[out_off + j] |= @as(u8, @truncate((in[i] >> in_shift) << out_shift));

                    const done = comptime @min(@min(d, todo), d - in_shift);
                    todo -= done;
                    in_shift += done;

                    if (in_shift == d) {
                        in_shift = 0;
                        i += 1;
                    }
                }
            }

            in_off += in_batch_size;
            out_off += out_batch_size;
        }

        return out;
    }

    // Set p to Decompress_q(m, d).
    fn decompress(comptime d: u8, in: *const [compressedSize(d)]u8) Poly {
        @setEvalBranchQuota(10000);
        const inLen = comptime @divTrunc(N * d, 8);
        comptime assert(inLen * 8 == d * N);
        var ret: Poly = undefined;
        var in_off: usize = 0;
        var out_off: usize = 0;

        const batch_size: usize = comptime lcm(@as(i16, d), 8);
        const in_batch_size: usize = comptime batch_size / 8;
        const out_batch_size: usize = comptime batch_size / d;

        while (out_off < N) {
            comptime var in_shift: usize = 0;
            comptime var j: usize = 0;
            comptime var i: usize = 0;
            inline while (i < out_batch_size) : (i += 1) {
                // First, unpack next coefficient.
                comptime var todo = d;
                var out: u16 = 0;

                inline while (todo > 0) {
                    const out_shift = comptime d - todo;
                    const m = comptime (1 << d) - 1;
                    out |= (@as(u16, in[in_off + j] >> in_shift) << out_shift) & m;

                    const done = comptime @min(@min(8, todo), 8 - in_shift);
                    todo -= done;
                    in_shift += done;

                    if (in_shift == 8) {
                        in_shift = 0;
                        j += 1;
                    }
                }

                // Decompress_q(x, d) = ⌈(q/2ᵈ)x⌋
                //                    = ⌊(q/2ᵈ)x+½⌋
                //                    = ⌊(qx + 2ᵈ⁻¹)/2ᵈ⌋
                //                    = (qx + (1<<(d-1))) >> d
                const qx = @as(u32, out) * @as(u32, Q);
                ret.cs[out_off + i] = @as(i16, @intCast((qx + (1 << (d - 1))) >> d));
            }

            in_off += in_batch_size;
            out_off += out_batch_size;
        }

        return ret;
    }

    // Returns the "pointwise" multiplication a o b.
    //
    // That is: invNTT(a o b) = invNTT(a) * invNTT(b).  Assumes a and b are in
    // Montgomery form.  Products between coefficients of a and b must be strictly
    // bounded in absolute value by 2¹⁵q.  a o b will be in Montgomery form and
    // bounded in absolute value by 2q.
    fn mulHat(a: Poly, b: Poly) Poly {
        // Recall from the discussion in ntt(), that a transformed polynomial is
        // an element of ℤ_q[x]/(x²-ζ) x … x  ℤ_q[x]/(x²+ζ¹²⁷);
        // that is: 128 degree-one polynomials instead of simply 256 elements
        // from ℤ_q as in the regular NTT.  So instead of pointwise multiplication,
        // we multiply the 128 pairs of degree-one polynomials modulo the
        // right equation:
        //
        //  (a₁ + a₂x)(b₁ + b₂x) = a₁b₁ + a₂b₂ζ' + (a₁b₂ + a₂b₁)x,
        //
        // where ζ' is the appropriate power of ζ.

        var p: Poly = undefined;
        var k: usize = 64;
        var i: usize = 0;
        while (i < N) : (i += 4) {
            const z = @as(i32, zetas[k]);
            k += 1;

            const a1b1 = montReduce(@as(i32, a.cs[i + 1]) * @as(i32, b.cs[i + 1]));
            const a0b0 = montReduce(@as(i32, a.cs[i]) * @as(i32, b.cs[i]));
            const a1b0 = montReduce(@as(i32, a.cs[i + 1]) * @as(i32, b.cs[i]));
            const a0b1 = montReduce(@as(i32, a.cs[i]) * @as(i32, b.cs[i + 1]));

            p.cs[i] = montReduce(a1b1 * z) + a0b0;
            p.cs[i + 1] = a0b1 + a1b0;

            const a3b3 = montReduce(@as(i32, a.cs[i + 3]) * @as(i32, b.cs[i + 3]));
            const a2b2 = montReduce(@as(i32, a.cs[i + 2]) * @as(i32, b.cs[i + 2]));
            const a3b2 = montReduce(@as(i32, a.cs[i + 3]) * @as(i32, b.cs[i + 2]));
            const a2b3 = montReduce(@as(i32, a.cs[i + 2]) * @as(i32, b.cs[i + 3]));

            p.cs[i + 2] = a2b2 - montReduce(a3b3 * z);
            p.cs[i + 3] = a2b3 + a3b2;
        }

        return p;
    }

    // Sample p from a centered binomial distribution with n=2η and p=½ - viz:
    // coefficients are in {-η, …, η} with probabilities
    //
    //  {ncr(0, 2η)/2^2η, ncr(1, 2η)/2^2η, …, ncr(2η,2η)/2^2η}
    fn noise(comptime eta: u8, nonce: u8, seed: *const [32]u8) Poly {
        var h = sha3.Shake256.init(.{});
        const suffix: [1]u8 = .{nonce};
        h.update(seed);
        h.update(&suffix);

        // The distribution at hand is exactly the same as that
        // of (a₁ + a₂ + … + a_η) - (b₁ + … + b_η) where a_i,b_i~U(1).
        // Thus we need 2η bits per coefficient.
        const buf_len = comptime 2 * eta * N / 8;
        var buf: [buf_len]u8 = undefined;
        h.squeeze(&buf);

        // buf is interpreted as a₁…a_ηb₁…b_ηa₁…a_ηb₁…b_η…. We process
        // multiple coefficients in one batch.

        const T = switch (builtin.target.cpu.arch) {
            .x86_64, .x86 => u32, // Generates better code on Intel CPUs
            else => u64, // u128 might be faster on some other CPUs.
        };

        comptime var batch_count: usize = undefined;
        comptime var batch_bytes: usize = undefined;
        comptime var mask: T = 0;
        comptime {
            batch_count = @bitSizeOf(T) / @as(usize, 2 * eta);
            while (@rem(N, batch_count) != 0 and batch_count > 0) : (batch_count -= 1) {}
            assert(batch_count > 0);
            assert(@rem(2 * eta * batch_count, 8) == 0);
            batch_bytes = 2 * eta * batch_count / 8;

            for (0..2 * eta * batch_count) |_| {
                mask <<= eta;
                mask |= 1;
            }
        }

        var ret: Poly = undefined;
        for (0..comptime N / batch_count) |i| {
            // Read coefficients into t. In the case of η=3,
            // we have t = a₁ + 2a₂ + 4a₃ + 8b₁ + 16b₂ + …
            var t: T = 0;
            inline for (0..batch_bytes) |j| {
                t |= @as(T, buf[batch_bytes * i + j]) << (8 * j);
            }

            // Accumelate `a's and `b's together by masking them out, shifting
            // and adding. For η=3, we have  d = a₁ + a₂ + a₃ + 8(b₁ + b₂ + b₃) + …
            var d: T = 0;
            inline for (0..eta) |j| {
                d += (t >> j) & mask;
            }

            // Extract each a and b separately and set coefficient in polynomial.
            inline for (0..batch_count) |j| {
                const mask2 = comptime (1 << eta) - 1;
                const a = @as(i16, @intCast((d >> (comptime (2 * j * eta))) & mask2));
                const b = @as(i16, @intCast((d >> (comptime ((2 * j + 1) * eta))) & mask2));
                ret.cs[batch_count * i + j] = a - b;
            }
        }

        return ret;
    }

    // Sample p uniformly from the given seed and x and y coordinates.
    fn uniform(seed: [32]u8, x: u8, y: u8) Poly {
        var h = sha3.Shake128.init(.{});
        const suffix: [2]u8 = .{ x, y };
        h.update(&seed);
        h.update(&suffix);

        const buf_len = sha3.Shake128.block_length; // rate SHAKE-128
        var buf: [buf_len]u8 = undefined;

        var ret: Poly = undefined;
        var i: usize = 0; // index into ret.cs
        outer: while (true) {
            h.squeeze(&buf);

            var j: usize = 0; // index into buf
            while (j < buf_len) : (j += 3) {
                const b0 = @as(u16, buf[j]);
                const b1 = @as(u16, buf[j + 1]);
                const b2 = @as(u16, buf[j + 2]);

                const ts: [2]u16 = .{
                    b0 | ((b1 & 0xf) << 8),
                    (b1 >> 4) | (b2 << 4),
                };

                inline for (ts) |t| {
                    if (t < Q) {
                        ret.cs[i] = @as(i16, @intCast(t));
                        i += 1;

                        if (i == N) {
                            break :outer;
                        }
                    }
                }
            }
        }

        return ret;
    }

    // Packs p.
    //
    // Assumes p is normalized (and not just Barrett reduced).
    fn toBytes(p: Poly) [bytes_length]u8 {
        var ret: [bytes_length]u8 = undefined;
        for (0..comptime N / 2) |i| {
            const t0 = @as(u16, @intCast(p.cs[2 * i]));
            const t1 = @as(u16, @intCast(p.cs[2 * i + 1]));
            ret[3 * i] = @as(u8, @truncate(t0));
            ret[3 * i + 1] = @as(u8, @truncate((t0 >> 8) | (t1 << 4)));
            ret[3 * i + 2] = @as(u8, @truncate(t1 >> 4));
        }
        return ret;
    }

    // Unpacks a Poly from buf.
    //
    // p will not be normalized; instead 0 ≤ p[i] < 4096.
    fn fromBytes(buf: *const [bytes_length]u8) Poly {
        var ret: Poly = undefined;
        for (0..comptime N / 2) |i| {
            const b0 = @as(i16, buf[3 * i]);
            const b1 = @as(i16, buf[3 * i + 1]);
            const b2 = @as(i16, buf[3 * i + 2]);
            ret.cs[2 * i] = b0 | ((b1 & 0xf) << 8);
            ret.cs[2 * i + 1] = (b1 >> 4) | b2 << 4;
        }
        return ret;
    }
};

// A vector of K polynomials.
fn Vec(comptime K: u8) type {
    return struct {
        ps: [K]Poly,

        const Self = @This();
        const bytes_length = K * Poly.bytes_length;

        fn compressedSize(comptime d: u8) usize {
            return Poly.compressedSize(d) * K;
        }

        fn ntt(a: Self) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                ret.ps[i] = a.ps[i].ntt();
            }
            return ret;
        }

        fn invNTT(a: Self) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                ret.ps[i] = a.ps[i].invNTT();
            }
            return ret;
        }

        fn normalize(a: Self) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                ret.ps[i] = a.ps[i].normalize();
            }
            return ret;
        }

        fn barrettReduce(a: Self) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                ret.ps[i] = a.ps[i].barrettReduce();
            }
            return ret;
        }

        fn add(a: Self, b: Self) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                ret.ps[i] = a.ps[i].add(b.ps[i]);
            }
            return ret;
        }

        fn sub(a: Self, b: Self) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                ret.ps[i] = a.ps[i].sub(b.ps[i]);
            }
            return ret;
        }

        // Samples v[i] from centered binomial distribution with the given η,
        // seed and nonce+i.
        fn noise(comptime eta: u8, nonce: u8, seed: *const [32]u8) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                ret.ps[i] = Poly.noise(eta, nonce + @as(u8, @intCast(i)), seed);
            }
            return ret;
        }

        // Sets p to the inner product of a and b using "pointwise" multiplication.
        //
        // See MulHat() and NTT() for a description of the multiplication.
        // Assumes a and b are in Montgomery form.  p will be in Montgomery form,
        // and its coefficients will be bounded in absolute value by 2kq.
        // If a and b are not in Montgomery form, then the action is the same
        // as "pointwise" multiplication followed by multiplying by R⁻¹, the inverse
        // of the Montgomery factor.
        fn dotHat(a: Self, b: Self) Poly {
            var ret: Poly = Poly.zero;
            for (0..K) |i| {
                ret = ret.add(a.ps[i].mulHat(b.ps[i]));
            }
            return ret;
        }

        fn compress(v: Self, comptime d: u8) [compressedSize(d)]u8 {
            const cs = comptime Poly.compressedSize(d);
            var ret: [compressedSize(d)]u8 = undefined;
            inline for (0..K) |i| {
                ret[i * cs .. (i + 1) * cs].* = v.ps[i].compress(d);
            }
            return ret;
        }

        fn decompress(comptime d: u8, buf: *const [compressedSize(d)]u8) Self {
            const cs = comptime Poly.compressedSize(d);
            var ret: Self = undefined;
            inline for (0..K) |i| {
                ret.ps[i] = Poly.decompress(d, buf[i * cs .. (i + 1) * cs]);
            }
            return ret;
        }

        /// Serializes the key into a byte array.
        fn toBytes(v: Self) [bytes_length]u8 {
            var ret: [bytes_length]u8 = undefined;
            inline for (0..K) |i| {
                ret[i * Poly.bytes_length .. (i + 1) * Poly.bytes_length].* = v.ps[i].toBytes();
            }
            return ret;
        }

        /// Deserializes the key from a byte array.
        fn fromBytes(buf: *const [bytes_length]u8) Self {
            var ret: Self = undefined;
            inline for (0..K) |i| {
                ret.ps[i] = Poly.fromBytes(
                    buf[i * Poly.bytes_length .. (i + 1) * Poly.bytes_length],
                );
            }
            return ret;
        }
    };
}

// A matrix of K vectors
fn Mat(comptime K: u8) type {
    return struct {
        const Self = @This();
        vs: [K]Vec(K),

        fn uniform(seed: [32]u8, comptime transposed: bool) Self {
            var ret: Self = undefined;
            var i: u8 = 0;
            while (i < K) : (i += 1) {
                var j: u8 = 0;
                while (j < K) : (j += 1) {
                    ret.vs[i].ps[j] = Poly.uniform(
                        seed,
                        if (transposed) i else j,
                        if (transposed) j else i,
                    );
                }
            }
            return ret;
        }

        // Returns transpose of A
        fn transpose(m: Self) Self {
            var ret: Self = undefined;
            for (0..K) |i| {
                for (0..K) |j| {
                    ret.vs[i].ps[j] = m.vs[j].ps[i];
                }
            }
            return ret;
        }
    };
}

// Returns `true` if a ≠ b.
fn ctneq(comptime len: usize, a: [len]u8, b: [len]u8) u1 {
    return 1 - @intFromBool(crypto.utils.timingSafeEql([len]u8, a, b));
}

// Copy src into dst given b = 1.
fn cmov(comptime len: usize, dst: *[len]u8, src: [len]u8, b: u1) void {
    const mask = @as(u8, 0) -% b;
    for (0..len) |i| {
        dst[i] ^= mask & (dst[i] ^ src[i]);
    }
}

test "MulHat" {
    var rnd = RndGen.init(0);

    for (0..100) |_| {
        const a = Poly.randAbsLeqQ(&rnd);
        const b = Poly.randAbsLeqQ(&rnd);

        const p2 = a.ntt().mulHat(b.ntt()).barrettReduce().invNTT().normalize();
        var p: Poly = undefined;

        @memset(&p.cs, 0);

        for (0..N) |i| {
            for (0..N) |j| {
                var v = montReduce(@as(i32, a.cs[i]) * @as(i32, b.cs[j]));
                var k = i + j;
                if (k >= N) {
                    // Recall Xᴺ = -1.
                    k -= N;
                    v = -v;
                }
                p.cs[k] = feBarrettReduce(v + p.cs[k]);
            }
        }

        p = p.toMont().normalize();

        try testing.expectEqual(p, p2);
    }
}

test "NTT" {
    var rnd = RndGen.init(0);

    for (0..1000) |_| {
        var p = Poly.randAbsLeqQ(&rnd);
        const q = p.toMont().normalize();
        p = p.ntt();

        for (0..N) |i| {
            try testing.expect(p.cs[i] <= 7 * Q and -7 * Q <= p.cs[i]);
        }

        p = p.normalize().invNTT();
        for (0..N) |i| {
            try testing.expect(p.cs[i] <= Q and -Q <= p.cs[i]);
        }

        p = p.normalize();

        try testing.expectEqual(p, q);
    }
}

test "Compression" {
    var rnd = RndGen.init(0);
    inline for (.{ 1, 4, 5, 10, 11 }) |d| {
        for (0..1000) |_| {
            const p = Poly.randNormalized(&rnd);
            const pp = p.compress(d);
            const pq = Poly.decompress(d, &pp).compress(d);
            try testing.expectEqual(pp, pq);
        }
    }
}

test "noise" {
    var seed: [32]u8 = undefined;
    for (&seed, 0..) |*s, i| {
        s.* = @as(u8, @intCast(i));
    }
    try testing.expectEqual(Poly.noise(3, 37, &seed).cs, .{
        0,  0,  1,  -1, 0,  2,  0,  -1, -1, 3,  0,  1,  -2, -2, 0,  1,  -2,
        1,  0,  -2, 3,  0,  0,  0,  1,  3,  1,  1,  2,  1,  -1, -1, -1, 0,
        1,  0,  1,  0,  2,  0,  1,  -2, 0,  -1, -1, -2, 1,  -1, -1, 2,  -1,
        1,  1,  2,  -3, -1, -1, 0,  0,  0,  0,  1,  -1, -2, -2, 0,  -2, 0,
        0,  0,  1,  0,  -1, -1, 1,  -2, 2,  0,  0,  2,  -2, 0,  1,  0,  1,
        1,  1,  0,  1,  -2, -1, -2, -1, 1,  0,  0,  0,  0,  0,  1,  0,  -1,
        -1, 0,  -1, 1,  0,  1,  0,  -1, -1, 0,  -2, 2,  0,  -2, 1,  -1, 0,
        1,  -1, -1, 2,  1,  0,  0,  -2, -1, 2,  0,  0,  0,  -1, -1, 3,  1,
        0,  1,  0,  1,  0,  2,  1,  0,  0,  1,  0,  1,  0,  0,  -1, -1, -1,
        0,  1,  3,  1,  0,  1,  0,  1,  -1, -1, -1, -1, 0,  0,  -2, -1, -1,
        2,  0,  1,  0,  1,  0,  2,  -2, 0,  1,  1,  -3, -1, -2, -1, 0,  1,
        0,  1,  -2, 2,  2,  1,  1,  0,  -1, 0,  -1, -1, 1,  0,  -1, 2,  1,
        -1, 1,  2,  -2, 1,  2,  0,  1,  2,  1,  0,  0,  2,  1,  2,  1,  0,
        2,  1,  0,  0,  -1, -1, 1,  -1, 0,  1,  -1, 2,  2,  0,  0,  -1, 1,
        1,  1,  1,  0,  0,  -2, 0,  -1, 1,  2,  0,  0,  1,  1,  -1, 1,  0,
        1,
    });
    try testing.expectEqual(Poly.noise(2, 37, &seed).cs, .{
        1,  0,  1,  -1, -1, -2, -1, -1, 2,  0,  -1, 0,  0,  -1,
        1,  1,  -1, 1,  0,  2,  -2, 0,  1,  2,  0,  0,  -1, 1,
        0,  -1, 1,  -1, 1,  2,  1,  1,  0,  -1, 1,  -1, -2, -1,
        1,  -1, -1, -1, 2,  -1, -1, 0,  0,  1,  1,  -1, 1,  1,
        1,  1,  -1, -2, 0,  1,  0,  0,  2,  1,  -1, 2,  0,  0,
        1,  1,  0,  -1, 0,  0,  -1, -1, 2,  0,  1,  -1, 2,  -1,
        -1, -1, -1, 0,  -2, 0,  2,  1,  0,  0,  0,  -1, 0,  0,
        0,  -1, -1, 0,  -1, -1, 0,  -1, 0,  0,  -2, 1,  1,  0,
        1,  0,  1,  0,  1,  1,  -1, 2,  0,  1,  -1, 1,  2,  0,
        0,  0,  0,  -1, -1, -1, 0,  1,  0,  -1, 2,  0,  0,  1,
        1,  1,  0,  1,  -1, 1,  2,  1,  0,  2,  -1, 1,  -1, -2,
        -1, -2, -1, 1,  0,  -2, -2, -1, 1,  0,  0,  0,  0,  1,
        0,  0,  0,  2,  2,  0,  1,  0,  -1, -1, 0,  2,  0,  0,
        -2, 1,  0,  2,  1,  -1, -2, 0,  0,  -1, 1,  1,  0,  0,
        2,  0,  1,  1,  -2, 1,  -2, 1,  1,  0,  2,  0,  -1, 0,
        -1, 0,  1,  2,  0,  1,  0,  -2, 1,  -2, -2, 1,  -1, 0,
        -1, 1,  1,  0,  0,  0,  1,  0,  -1, 1,  1,  0,  0,  0,
        0,  1,  0,  1,  -1, 0,  1,  -1, -1, 2,  0,  0,  1,  -1,
        0,  1,  -1, 0,
    });
}

test "uniform sampling" {
    var seed: [32]u8 = undefined;
    for (&seed, 0..) |*s, i| {
        s.* = @as(u8, @intCast(i));
    }
    try testing.expectEqual(Poly.uniform(seed, 1, 0).cs, .{
        797,  993,  161,  6,    2608, 2385, 2096, 2661, 1676, 247,  2440,
        342,  634,  194,  1570, 2848, 986,  684,  3148, 3208, 2018, 351,
        2288, 612,  1394, 170,  1521, 3119, 58,   596,  2093, 1549, 409,
        2156, 1934, 1730, 1324, 388,  446,  418,  1719, 2202, 1812, 98,
        1019, 2369, 214,  2699, 28,   1523, 2824, 273,  402,  2899, 246,
        210,  1288, 863,  2708, 177,  3076, 349,  44,   949,  854,  1371,
        957,  292,  2502, 1617, 1501, 254,  7,    1761, 2581, 2206, 2655,
        1211, 629,  1274, 2358, 816,  2766, 2115, 2985, 1006, 2433, 856,
        2596, 3192, 1,    1378, 2345, 707,  1891, 1669, 536,  1221, 710,
        2511, 120,  1176, 322,  1897, 2309, 595,  2950, 1171, 801,  1848,
        695,  2912, 1396, 1931, 1775, 2904, 893,  2507, 1810, 2873, 253,
        1529, 1047, 2615, 1687, 831,  1414, 965,  3169, 1887, 753,  3246,
        1937, 115,  2953, 586,  545,  1621, 1667, 3187, 1654, 1988, 1857,
        512,  1239, 1219, 898,  3106, 391,  1331, 2228, 3169, 586,  2412,
        845,  768,  156,  662,  478,  1693, 2632, 573,  2434, 1671, 173,
        969,  364,  1663, 2701, 2169, 813,  1000, 1471, 720,  2431, 2530,
        3161, 733,  1691, 527,  2634, 335,  26,   2377, 1707, 767,  3020,
        950,  502,  426,  1138, 3208, 2607, 2389, 44,   1358, 1392, 2334,
        875,  2097, 173,  1697, 2578, 942,  1817, 974,  1165, 2853, 1958,
        2973, 3282, 271,  1236, 1677, 2230, 673,  1554, 96,   242,  1729,
        2518, 1884, 2272, 71,   1382, 924,  1807, 1610, 456,  1148, 2479,
        2152, 238,  2208, 2329, 713,  1175, 1196, 757,  1078, 3190, 3169,
        708,  3117, 154,  1751, 3225, 1364, 154,  23,   2842, 1105, 1419,
        79,   5,    2013,
    });
}

test "Polynomial packing" {
    var rnd = RndGen.init(0);

    for (0..1000) |_| {
        const p = Poly.randNormalized(&rnd);
        try testing.expectEqual(Poly.fromBytes(&p.toBytes()), p);
    }
}

test "Test inner PKE" {
    var seed: [32]u8 = undefined;
    var pt: [32]u8 = undefined;
    for (&seed, &pt, 0..) |*s, *p, i| {
        s.* = @as(u8, @intCast(i));
        p.* = @as(u8, @intCast(i + 32));
    }
    inline for (modes) |mode| {
        for (0..100) |i| {
            var pk: mode.InnerPk = undefined;
            var sk: mode.InnerSk = undefined;
            seed[0] = @as(u8, @intCast(i));
            mode.innerKeyFromSeed(seed, &pk, &sk);
            for (0..10) |j| {
                seed[1] = @as(u8, @intCast(j));
                try testing.expectEqual(sk.decrypt(&pk.encrypt(&pt, &seed)), pt);
            }
        }
    }
}

test "Test happy flow" {
    var seed: [64]u8 = undefined;
    for (&seed, 0..) |*s, i| {
        s.* = @as(u8, @intCast(i));
    }
    inline for (modes) |mode| {
        for (0..100) |i| {
            seed[0] = @as(u8, @intCast(i));
            const kp = try mode.KeyPair.create(seed);
            const sk = try mode.SecretKey.fromBytes(&kp.secret_key.toBytes());
            try testing.expectEqual(sk, kp.secret_key);
            const pk = try mode.PublicKey.fromBytes(&kp.public_key.toBytes());
            try testing.expectEqual(pk, kp.public_key);
            for (0..10) |j| {
                seed[1] = @as(u8, @intCast(j));
                const e = pk.encaps(seed[0..32].*);
                try testing.expectEqual(e.shared_secret, try sk.decaps(&e.ciphertext));
            }
        }
    }
}

// Code to test NIST Known Answer Tests (KAT), see PQCgenKAT.c.

const sha2 = crypto.hash.sha2;

test "NIST KAT test" {
    inline for (.{
        .{ Kyber512, "e9c2bd37133fcb40772f81559f14b1f58dccd1c816701be9ba6214d43baf4547" },
        .{ Kyber1024, "89248f2f33f7f4f7051729111f3049c409a933ec904aedadf035f30fa5646cd5" },
        .{ Kyber768, "a1e122cad3c24bc51622e4c242d8b8acbcd3f618fee4220400605ca8f9ea02c2" },
    }) |modeHash| {
        const mode = modeHash[0];
        var seed: [48]u8 = undefined;
        for (&seed, 0..) |*s, i| {
            s.* = @as(u8, @intCast(i));
        }
        var f = sha2.Sha256.init(.{});
        const fw = f.writer();
        var g = NistDRBG.init(seed);
        try std.fmt.format(fw, "# {s}\n\n", .{mode.name});
        for (0..100) |i| {
            g.fill(&seed);
            try std.fmt.format(fw, "count = {}\n", .{i});
            try std.fmt.format(fw, "seed = {s}\n", .{std.fmt.fmtSliceHexUpper(&seed)});
            var g2 = NistDRBG.init(seed);

            // This is not equivalent to g2.fill(kseed[:]). As the reference
            // implementation calls randombytes twice generating the keypair,
            // we have to do that as well.
            var kseed: [64]u8 = undefined;
            var eseed: [32]u8 = undefined;
            g2.fill(kseed[0..32]);
            g2.fill(kseed[32..64]);
            g2.fill(&eseed);
            const kp = try mode.KeyPair.create(kseed);
            const e = kp.public_key.encaps(eseed);
            const ss2 = try kp.secret_key.decaps(&e.ciphertext);
            try testing.expectEqual(ss2, e.shared_secret);
            try std.fmt.format(fw, "pk = {s}\n", .{std.fmt.fmtSliceHexUpper(&kp.public_key.toBytes())});
            try std.fmt.format(fw, "sk = {s}\n", .{std.fmt.fmtSliceHexUpper(&kp.secret_key.toBytes())});
            try std.fmt.format(fw, "ct = {s}\n", .{std.fmt.fmtSliceHexUpper(&e.ciphertext)});
            try std.fmt.format(fw, "ss = {s}\n\n", .{std.fmt.fmtSliceHexUpper(&e.shared_secret)});
        }

        var out: [32]u8 = undefined;
        f.final(&out);
        var outHex: [64]u8 = undefined;
        _ = try std.fmt.bufPrint(&outHex, "{s}", .{std.fmt.fmtSliceHexLower(&out)});
        try testing.expectEqual(outHex, modeHash[1].*);
    }
}

const NistDRBG = struct {
    key: [32]u8,
    v: [16]u8,

    fn incV(g: *NistDRBG) void {
        var j: usize = 15;
        while (j >= 0) : (j -= 1) {
            if (g.v[j] == 255) {
                g.v[j] = 0;
            } else {
                g.v[j] += 1;
                break;
            }
        }
    }

    // AES256_CTR_DRBG_Update(pd, &g.key, &g.v).
    fn update(g: *NistDRBG, pd: ?[48]u8) void {
        var buf: [48]u8 = undefined;
        const ctx = crypto.core.aes.Aes256.initEnc(g.key);
        var i: usize = 0;
        while (i < 3) : (i += 1) {
            g.incV();
            var block: [16]u8 = undefined;
            ctx.encrypt(&block, &g.v);
            buf[i * 16 ..][0..16].* = block;
        }
        if (pd) |p| {
            for (&buf, p) |*b, x| {
                b.* ^= x;
            }
        }
        g.key = buf[0..32].*;
        g.v = buf[32..48].*;
    }

    // randombytes.
    fn fill(g: *NistDRBG, out: []u8) void {
        var block: [16]u8 = undefined;
        var dst = out;

        const ctx = crypto.core.aes.Aes256.initEnc(g.key);
        while (dst.len > 0) {
            g.incV();
            ctx.encrypt(&block, &g.v);
            if (dst.len < 16) {
                @memcpy(dst, block[0..dst.len]);
                break;
            }
            dst[0..block.len].* = block;
            dst = dst[16..dst.len];
        }
        g.update(null);
    }

    fn init(seed: [48]u8) NistDRBG {
        var ret: NistDRBG = .{ .key = .{0} ** 32, .v = .{0} ** 16 };
        ret.update(seed);
        return ret;
    }
};

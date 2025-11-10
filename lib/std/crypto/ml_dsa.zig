//! Module-Lattice-Based Digital Signature Algorithm (ML-DSA) as specified in NIST FIPS 204.
//!
//! ML-DSA is a post-quantum secure digital signature scheme based on the hardness
//! of the Module Learning With Errors (MLWE) and Module Short Integer Solution (MSIS)
//! problems over module lattices.
//!
//! We provide three parameter sets:
//!
//! - ML-DSA-44: NIST security category 2 (128-bit security)
//! - ML-DSA-65: NIST security category 3 (192-bit security)
//! - ML-DSA-87: NIST security category 5 (256-bit security)

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const assert = std.debug.assert;
const crypto = std.crypto;
const errors = std.crypto.errors;
const math = std.math;
const mem = std.mem;
const sha3 = crypto.hash.sha3;

const ContextTooLongError = errors.ContextTooLongError;
const EncodingError = errors.EncodingError;
const SignatureVerificationError = errors.SignatureVerificationError;

/// ML-DSA-44 (Module-Lattice-Based Digital Signature Algorithm, 44 parameter set)
/// as specified in NIST FIPS 204.
///
/// This is a post-quantum signature scheme providing NIST security category 2,
/// which is roughly equivalent to the security of SHA-256 or AES-128.
///
/// Key sizes:
///
/// - Public key: 1312 bytes
/// - Secret key: 2560 bytes
/// - Signature: 2420 bytes
///
/// Example usage:
///
/// ```zig
/// const kp = MLDSA44.KeyPair.generate();
/// const msg = "Hello, post-quantum world!";
/// const sig = try kp.sign(msg, null);
/// try sig.verify(msg, kp.public_key);
/// ```
pub const MLDSA44 = MLDSAImpl(.{
    .name = "ML-DSA-44",
    .k = 4,
    .l = 4,
    .eta = 2,
    .omega = 80,
    .tau = 39,
    .gamma1_bits = 17,
    .gamma2 = 95232, // (Q-1)/88
    .tr_size = 64,
    .ctilde_size = 32,
});

/// ML-DSA-65 (Module-Lattice-Based Digital Signature Algorithm, 65 parameter set)
/// as specified in NIST FIPS 204.
///
/// This is a post-quantum signature scheme providing NIST security category 3,
/// which is roughly equivalent to the security of SHA-384 or AES-192.
///
/// Key sizes:
///
/// - Public key: 1952 bytes
/// - Secret key: 4032 bytes
/// - Signature: 3309 bytes
///
/// This parameter set offers higher security than ML-DSA-44 at the cost of
/// larger keys and signatures.
pub const MLDSA65 = MLDSAImpl(.{
    .name = "ML-DSA-65",
    .k = 6,
    .l = 5,
    .eta = 4,
    .omega = 55,
    .tau = 49,
    .gamma1_bits = 19,
    .gamma2 = 261888, // (Q-1)/32
    .tr_size = 64,
    .ctilde_size = 48,
});

/// ML-DSA-87 (Module-Lattice-Based Digital Signature Algorithm, 87 parameter set)
/// as specified in NIST FIPS 204.
///
/// This is a post-quantum signature scheme providing NIST security category 5,
/// which is roughly equivalent to the security of SHA-512 or AES-256.
///
/// Key sizes:
///
/// - Public key: 2592 bytes
/// - Secret key: 4896 bytes
/// - Signature: 4627 bytes
///
/// This parameter set offers the highest security level among the three ML-DSA
/// variants, suitable for applications requiring maximum security assurance.
pub const MLDSA87 = MLDSAImpl(.{
    .name = "ML-DSA-87",
    .k = 8,
    .l = 7,
    .eta = 2,
    .omega = 75,
    .tau = 60,
    .gamma1_bits = 19,
    .gamma2 = 261888, // (Q-1)/32
    .tr_size = 64,
    .ctilde_size = 64,
});

const N: usize = 256; // Degree of polynomials
const Q: u32 = 8380417; // Modulus: 2^23 - 2^13 + 1
const Q_BITS: u32 = 23;
const D: u32 = 13; // Dropped bits in power2Round

// Montgomery constant R = 2^32 mod q
const R: u64 = 1 << 32;

// Q^(-1) mod 2^32 = -(q^-1) mod 2^32
const Q_INV: u32 = 4236238847;

// (256)^(-1) * R^2 mod q, used in inverse NTT
const R_OVER_256: u32 = 41978;

// Primitive 512th root of unity
const ZETA: u32 = 1753;

const Params = struct {
    name: []const u8,

    // Matrix dimensions
    k: u8, // Height of matrix A
    l: u8, // Width of matrix A

    // Sampling parameter
    eta: u8, // Bound for secret coefficients

    // Hint parameters
    omega: u16, // Maximum number of hint bits

    // Challenge parameter
    tau: u16, // Weight of challenge polynomial

    // Rounding parameters
    gamma1_bits: u8, // Bits for gamma1
    gamma2: u32, // Parameter for decompose

    // Sizes
    tr_size: usize, // Size of tr hash
    ctilde_size: usize, // Size of challenge hash
};

const Poly = struct {
    cs: [N]u32,

    const zero: Poly = .{ .cs = .{0} ** N };

    // Add two polynomials (no normalization)
    fn add(a: Poly, b: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = a.cs[i] + b.cs[i];
        }
        return ret;
    }

    // Subtract two polynomials (assumes b coefficients < 2q)
    fn sub(a: Poly, b: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = a.cs[i] +% (@as(u32, 2 * Q) -% b.cs[i]);
        }
        return ret;
    }

    // Reduce each coefficient to < 2q
    fn reduceLe2Q(p: Poly) Poly {
        var ret = p;
        for (0..N) |i| {
            ret.cs[i] = le2Q(ret.cs[i]);
        }
        return ret;
    }

    // Normalize coefficients to [0, q)
    fn normalize(p: Poly) Poly {
        var ret = p;
        for (0..N) |i| {
            ret.cs[i] = modQ(ret.cs[i]);
        }
        return ret;
    }

    // Normalize assuming coefficients already < 2q
    fn normalizeAssumingLe2Q(p: Poly) Poly {
        var ret = p;
        for (0..N) |i| {
            ret.cs[i] = le2qModQ(ret.cs[i]);
        }
        return ret;
    }

    // Pointwise multiplication in NTT domain (Montgomery form)
    fn mulHat(a: Poly, b: Poly) Poly {
        var ret: Poly = undefined;
        for (0..N) |i| {
            ret.cs[i] = montReduceLe2Q(@as(u64, a.cs[i]) * @as(u64, b.cs[i]));
        }
        return ret;
    }

    // Forward NTT
    fn ntt(p: Poly) Poly {
        var ret = p;
        ret.nttInPlace();
        return ret;
    }

    // In-place forward NTT
    fn nttInPlace(p: *Poly) void {
        var k: usize = 0;
        var l: usize = N / 2;

        while (l > 0) : (l >>= 1) {
            var offset: usize = 0;
            while (offset < N - l) : (offset += 2 * l) {
                k += 1;
                const zeta: u64 = zetas[k];

                for (offset..offset + l) |j| {
                    const t = montReduceLe2Q(zeta * @as(u64, p.cs[j + l]));
                    p.cs[j + l] = p.cs[j] +% (2 * Q -% t);
                    p.cs[j] +%= t;
                }
            }
        }
    }

    // Inverse NTT
    fn invNTT(p: Poly) Poly {
        var ret = p;
        ret.invNTTInPlace();
        return ret;
    }

    // In-place inverse NTT
    fn invNTTInPlace(p: *Poly) void {
        var k: usize = 0;
        var l: usize = 1;

        while (l < N) : (l <<= 1) {
            var offset: usize = 0;
            while (offset < N - l) : (offset += 2 * l) {
                const zeta: u64 = inv_zetas[k];
                k += 1;

                for (offset..offset + l) |j| {
                    const t = p.cs[j];
                    p.cs[j] = t +% p.cs[j + l];
                    p.cs[j + l] = montReduceLe2Q(zeta * @as(u64, t +% 256 * Q -% p.cs[j + l]));
                }
            }
        }

        for (0..N) |j| {
            p.cs[j] = montReduceLe2Q(@as(u64, R_OVER_256) * @as(u64, p.cs[j]));
        }
    }

    /// Apply Power2Round to all coefficients
    /// Returns both t0 and t1 polynomials
    fn power2RoundPoly(p: Poly) struct { t0: Poly, t1: Poly } {
        var t0 = Poly.zero;
        var t1 = Poly.zero;
        for (0..N) |i| {
            const result = power2Round(p.cs[i]);
            t0.cs[i] = result.a0_plus_q;
            t1.cs[i] = result.a1;
        }
        return .{ .t0 = t0, .t1 = t1 };
    }

    // Check if infinity norm exceeds bound
    fn exceeds(p: Poly, bound: u32) bool {
        var result: u32 = 0;
        for (0..N) |i| {
            const x = @as(i32, @intCast((Q - 1) / 2)) - @as(i32, @intCast(p.cs[i]));
            const abs_x = x ^ (x >> 31);
            const norm = @as(i32, @intCast((Q - 1) / 2)) - abs_x;
            const exceeds_bit = @intFromBool(@as(u32, @intCast(norm)) >= bound);
            result |= exceeds_bit;
        }
        return result != 0;
    }
};

fn PolyVec(comptime len: u8) type {
    return struct {
        ps: [len]Poly,

        const Self = @This();
        const zero: Self = .{ .ps = .{Poly.zero} ** len };

        /// Apply a unary operation to each polynomial in the vector
        fn map(v: Self, comptime op: fn (Poly) Poly) Self {
            var ret: Self = undefined;
            inline for (0..len) |i| {
                ret.ps[i] = op(v.ps[i]);
            }
            return ret;
        }

        /// Apply a binary operation pairwise to two vectors
        fn mapBinary(a: Self, b: Self, comptime op: fn (Poly, Poly) Poly) Self {
            var ret: Self = undefined;
            inline for (0..len) |i| {
                ret.ps[i] = op(a.ps[i], b.ps[i]);
            }
            return ret;
        }

        /// Apply a binary operation between a vector and a scalar polynomial
        fn mapBinaryPoly(v: Self, scalar: Poly, comptime op: fn (Poly, Poly) Poly) Self {
            var ret: Self = undefined;
            inline for (0..len) |i| {
                ret.ps[i] = op(v.ps[i], scalar);
            }
            return ret;
        }

        fn add(a: Self, b: Self) Self {
            return mapBinary(a, b, Poly.add);
        }

        fn sub(a: Self, b: Self) Self {
            return mapBinary(a, b, Poly.sub);
        }

        fn ntt(v: Self) Self {
            return map(v, Poly.ntt);
        }

        fn invNTT(v: Self) Self {
            return map(v, Poly.invNTT);
        }

        fn normalize(v: Self) Self {
            return map(v, Poly.normalize);
        }

        fn reduceLe2Q(v: Self) Self {
            return map(v, Poly.reduceLe2Q);
        }

        fn normalizeAssumingLe2Q(v: Self) Self {
            return map(v, Poly.normalizeAssumingLe2Q);
        }

        // Check if any polynomial in the vector exceeds the bound
        fn exceeds(v: Self, bound: u32) bool {
            var result = false;
            for (0..len) |i| {
                result = result or v.ps[i].exceeds(bound);
            }
            return result;
        }

        /// Apply Power2Round to each polynomial in the vector
        /// Returns both t0 and t1 vectors
        fn power2Round(v: Self, t0_out: *Self) Self {
            var t1: Self = undefined;
            for (0..len) |i| {
                const result = v.ps[i].power2RoundPoly();
                t0_out.ps[i] = result.t0;
                t1.ps[i] = result.t1;
            }
            return t1;
        }

        /// Generic packing function for vectors
        fn packWith(
            v: Self,
            buf: []u8,
            comptime poly_size: usize,
            comptime pack_fn: fn (Poly, []u8) void,
        ) void {
            inline for (0..len) |i| {
                const offset = i * poly_size;
                pack_fn(v.ps[i], buf[offset..][0..poly_size]);
            }
        }

        /// Generic unpacking function for vectors
        fn unpackWith(
            comptime poly_size: usize,
            comptime unpack_fn: fn ([]const u8) Poly,
            buf: []const u8,
        ) Self {
            var result: Self = undefined;
            inline for (0..len) |i| {
                const offset = i * poly_size;
                result.ps[i] = unpack_fn(buf[offset..][0..poly_size]);
            }
            return result;
        }

        /// Pack T1 vector to bytes
        fn packT1(v: Self, buf: []u8) void {
            const poly_size = (N * (Q_BITS - D)) / 8;
            packWith(v, buf, poly_size, polyPackT1);
        }

        /// Unpack T1 vector from bytes
        fn unpackT1(bytes: []const u8) Self {
            const poly_size = (N * (Q_BITS - D)) / 8;
            return unpackWith(poly_size, polyUnpackT1, bytes);
        }

        /// Pack T0 vector to bytes
        fn packT0(v: Self, buf: []u8) void {
            const poly_size = (N * D) / 8;
            packWith(v, buf, poly_size, polyPackT0);
        }

        /// Unpack T0 vector from bytes
        fn unpackT0(buf: []const u8) Self {
            const poly_size = (N * D) / 8;
            return unpackWith(poly_size, polyUnpackT0, buf);
        }

        /// Pack vector with coefficients in [-eta, eta]
        fn packLeqEta(v: Self, comptime eta: u8, buf: []u8) void {
            const poly_size = if (eta == 2) 96 else 128;
            const pack_fn = struct {
                fn pack(p: Poly, b: []u8) void {
                    polyPackLeqEta(p, eta, b);
                }
            }.pack;
            packWith(v, buf, poly_size, pack_fn);
        }

        /// Unpack vector with coefficients in [-eta, eta]
        fn unpackLeqEta(comptime eta: u8, buf: []const u8) Self {
            const poly_size = if (eta == 2) 96 else 128;
            const unpack_fn = struct {
                fn unpack(b: []const u8) Poly {
                    return polyUnpackLeqEta(eta, b);
                }
            }.unpack;
            return unpackWith(poly_size, unpack_fn, buf);
        }

        /// Pack vector of polynomials with coefficients < gamma1
        fn packLeGamma1(v: Self, comptime gamma1_bits: u8, buf: []u8) void {
            const poly_size = ((gamma1_bits + 1) * N) / 8;
            const pack_fn = struct {
                fn pack(p: Poly, b: []u8) void {
                    polyPackLeGamma1(p, gamma1_bits, b);
                }
            }.pack;
            packWith(v, buf, poly_size, pack_fn);
        }

        /// Unpack vector of polynomials with coefficients < gamma1
        fn unpackLeGamma1(comptime gamma1_bits: u8, buf: []const u8) Self {
            const poly_size = ((gamma1_bits + 1) * N) / 8;
            const unpack_fn = struct {
                fn unpack(b: []const u8) Poly {
                    return polyUnpackLeGamma1(gamma1_bits, b);
                }
            }.unpack;
            return unpackWith(poly_size, unpack_fn, buf);
        }

        /// Pack high bits w1 for signature verification
        fn packW1(v: Self, comptime gamma1_bits: u8, buf: []u8) void {
            const poly_size = (N * (Q_BITS - gamma1_bits)) / 8;
            const pack_fn = struct {
                fn pack(p: Poly, b: []u8) void {
                    polyPackW1(p, gamma1_bits, b);
                }
            }.pack;
            packWith(v, buf, poly_size, pack_fn);
        }

        /// Decompose each polynomial in the vector into high and low bits
        fn decomposeVec(v: Self, comptime gamma2: u32, w0_out: *Self) Self {
            var w1: Self = undefined;
            for (0..len) |i| {
                for (0..N) |j| {
                    const r = decompose(v.ps[i].cs[j], gamma2);
                    w0_out.ps[i].cs[j] = r.a0_plus_q;
                    w1.ps[i].cs[j] = r.a1;
                }
            }
            return w1;
        }

        /// Create hints for vector, returns hint population count
        fn makeHintVec(w0mcs2pct0: Self, w1: Self, comptime gamma2: u32) struct { hint: Self, pop: u32 } {
            var hint: Self = undefined;
            var pop: u32 = 0;
            for (0..len) |i| {
                const result = polyMakeHint(w0mcs2pct0.ps[i], w1.ps[i], gamma2);
                hint.ps[i] = result.hint;
                pop += result.count;
            }
            return .{ .hint = hint, .pop = pop };
        }

        /// Apply hints to recover high bits
        fn useHint(v: Self, hint: Self, comptime gamma2: u32) Self {
            var result: Self = undefined;
            for (0..len) |i| {
                result.ps[i] = polyUseHint(v.ps[i], hint.ps[i], gamma2);
            }
            return result;
        }

        /// Multiply vector by 2^D (left shift)
        fn mulBy2toD(v: Self) Self {
            var result: Self = undefined;
            for (0..len) |i| {
                for (0..N) |j| {
                    result.ps[i].cs[j] = v.ps[i].cs[j] << D;
                }
            }
            return result;
        }

        /// Sample vector with coefficients uniformly in (-gamma1, gamma1]
        /// Wraps expandMask (FIPS 204: ExpandMask)
        fn deriveUniformLeGamma1(comptime gamma1_bits: u8, seed: *const [64]u8, nonce: u16) Self {
            var result: Self = undefined;
            for (0..len) |i| {
                result.ps[i] = expandMask(gamma1_bits, seed, nonce + @as(u16, @intCast(i)));
            }
            return result;
        }

        /// Pack hints into bytes
        /// Format: for each polynomial, find positions where hint[i]=1, encode those positions
        fn packHint(v: Self, comptime omega: u16, buf: []u8) bool {
            var idx: usize = 0;
            var count: u32 = 0;

            for (0..len) |i| {
                for (0..N) |j| {
                    if (v.ps[i].cs[j] != 0) {
                        count += 1;
                    }
                }
            }

            if (count > omega) {
                return false;
            }

            // Hint encoding format per FIPS 204:
            // First omega bytes: positions of set bits across all polynomials
            // Last len bytes: boundary indices showing where each polynomial's hints end
            for (0..len) |i| {
                for (0..N) |j| {
                    if (v.ps[i].cs[j] != 0) {
                        buf[idx] = @intCast(j);
                        idx += 1;
                    }
                }
                buf[omega + i] = @intCast(idx);
            }

            while (idx < omega) : (idx += 1) {
                buf[idx] = 0;
            }

            return true;
        }

        /// Unpack hints from bytes
        fn unpackHint(comptime omega: u16, buf: []const u8) ?Self {
            var result: Self = .{ .ps = .{Poly.zero} ** len };
            var prev_sop: u8 = 0; // previous switch-over-point

            for (0..len) |i| {
                const sop = buf[omega + i]; // switch-over-point
                if (sop < prev_sop or sop > omega) {
                    return null; // ensures switch-over-points are increasing
                }

                var j = prev_sop;
                while (j < sop) : (j += 1) {
                    // Validation: indices must be strictly increasing within each polynomial
                    if (j > prev_sop and buf[j] <= buf[j - 1]) {
                        return null;
                    }
                    const pos = buf[j];
                    if (pos >= N) {
                        return null;
                    }
                    result.ps[i].cs[pos] = 1;
                }
                prev_sop = sop;
            }

            var j = prev_sop;
            while (j < omega) : (j += 1) {
                if (buf[j] != 0) {
                    return null;
                }
            }

            return result;
        }
    };
}

// Matrix of k x l polynomials

fn Mat(comptime k: u8, comptime l: u8) type {
    return struct {
        rows: [k]PolyVec(l),

        const Self = @This();
        const VecL = PolyVec(l);
        const VecK = PolyVec(k);

        /// Expand matrix A from seed rho using SHAKE-128
        /// This is the ExpandA function from FIPS 204
        fn derive(rho: *const [32]u8) Self {
            var m: Self = undefined;
            for (0..k) |i| {
                if (i + 1 < k) {
                    @prefetch(&m.rows[i + 1], .{ .rw = .write, .locality = 2 });
                }
                for (0..l) |j| {
                    // Nonce is i*256 + j
                    const nonce: u16 = (@as(u16, @intCast(i)) << 8) | @as(u16, @intCast(j));
                    m.rows[i].ps[j] = polyDeriveUniform(rho, nonce);
                }
            }
            return m;
        }

        /// Multiply matrix by vector in NTT domain and return result in regular domain.
        /// Takes a vector in NTT form and returns the product in regular form.
        fn mulVec(self: Self, v_hat: VecL) VecK {
            var result = VecK.zero;
            for (0..k) |i| {
                result.ps[i] = dotHat(l, self.rows[i], v_hat);
                result.ps[i] = result.ps[i].reduceLe2Q();
                result.ps[i] = result.ps[i].invNTT();
            }
            return result;
        }

        /// Multiply matrix by vector in NTT domain and return result in NTT domain.
        /// Takes a vector in NTT form and returns the product in NTT form.
        fn mulVecHat(self: Self, v_hat: VecL) VecK {
            var result: VecK = undefined;
            for (0..k) |i| {
                result.ps[i] = dotHat(l, self.rows[i], v_hat);
            }
            return result;
        }
    };
}

// Dot product in NTT domain
fn dotHat(comptime len: u8, a: PolyVec(len), b: PolyVec(len)) Poly {
    var ret = Poly.zero;
    for (0..len) |i| {
        const prod = a.ps[i].mulHat(b.ps[i]);
        ret = ret.add(prod);
    }
    return ret;
}

// Modular arithmetic operations

// Reduce x to [0, 2q) using the fact that 2^23 = 2^13 - 1 (mod q)
fn le2Q(x: u32) u32 {
    // Write x = x1 * 2^23 + x2 with x2 < 2^23 and x1 < 2^9
    // Then x = x2 + x1 * 2^13 - x1 (mod q)
    // and x2 + x1 * 2^13 - x1 <= 2^23 + 2^13 < 2q
    const x1 = x >> 23;
    const x2 = x & 0x7FFFFF; // 2^23 - 1
    return x2 +% (x1 << 13) -% x1;
}

// Reduce x to [0, q)
fn modQ(x: u32) u32 {
    return le2qModQ(le2Q(x));
}

// Given x < 2q, reduce to [0, q)
fn le2qModQ(x: u32) u32 {
    const r = x -% Q;
    const mask = signMask(u32, r);
    return r +% (mask & Q);
}

// Montgomery reduction: for x < q*2^32, return y < 2q where y ≡ x*R^(-1) (mod q)
// where R = 2^32. This is used for efficient modular multiplication in NTT operations.
fn montReduceLe2Q(x: u64) u32 {
    const m = (x *% Q_INV) & 0xffffffff;
    return @truncate((x +% m * @as(u64, Q)) >> 32);
}

// Precomputed zetas for NTT (Montgomery form)
// zetas[i] = zeta^brv(i) * R mod q
const zetas = computeZetas();

fn computeZetas() [N]u32 {
    @setEvalBranchQuota(100000);
    var ret: [N]u32 = undefined;

    for (0..N) |i| {
        const brv_i = @bitReverse(@as(u8, @intCast(i)));
        const power = modularPow(u32, ZETA, brv_i, Q);
        ret[i] = toMont(power);
    }

    return ret;
}

// Precomputed inverse zetas for inverse NTT
const inv_zetas = computeInvZetas();

fn computeInvZetas() [N]u32 {
    @setEvalBranchQuota(100000);
    var ret: [N]u32 = undefined;

    const inv_zeta = modularInverse(u32, ZETA, Q);

    for (0..N) |i| {
        const idx = 255 - i;
        const brv_idx = @bitReverse(@as(u8, @intCast(idx)));

        // Exponent is -(brv_idx - 256) = 256 - brv_idx
        const exp: u32 = @as(u32, 256) - brv_idx;

        // Compute inv_zeta^exp
        const power = modularPow(u32, inv_zeta, exp, Q);

        // Convert to Montgomery form
        ret[i] = toMont(power);
    }

    return ret;
}

// Convert to Montgomery form: x -> x * R mod q
fn toMont(x: u32) u32 {
    // R = 2^32, R mod q can be computed as:
    // 2^32 mod q = 2^32 mod (2^23 - 2^13 + 1)
    // Using the identity 2^23 = 2^13 - 1 (mod q), we can reduce 2^32
    // But it's easier to just do: return montReduce(x * R^2 mod q)
    // where R^2 mod q is precomputed

    // Computing R^2 mod q:
    // R = 2^32, so R^2 = 2^64
    // We can compute this by noting that R mod q first:
    // 2^32 = 2^32 mod q
    // But let's use a simpler approach: multiply x by R in the Montgomery domain
    // Actually, the simplest is: x * R mod q = montReduceLe2Q(x * R^2 mod q)

    // Precompute R^2 mod q at comptime
    const r_mod_q = comptime blk: {
        // 2^32 mod q - compute by successive squaring
        var r: u64 = 1;
        for (0..32) |_| {
            r = (r * 2) % Q;
        }
        break :blk @as(u32, @intCast(r));
    };

    const r2_mod_q = comptime blk: {
        const r = @as(u64, r_mod_q);
        break :blk @as(u32, @intCast((r * r) % Q));
    };

    return montReduceLe2Q(@as(u64, x) * @as(u64, r2_mod_q));
}

/// Splits 0 ≤ a < Q into a0 and a1 with a = a1*2^D + a0
/// and -2^(D-1) < a0 ≤ 2^(D-1). Returns a0 + Q and a1.
/// FIPS 204: Power2Round (Algorithm 19)
fn power2Round(a: u32) struct { a0_plus_q: u32, a1: u32 } {
    // We effectively compute a0 = a mod± 2^D
    //                    and a1 = (a - a0) / 2^D
    var a0 = a & ((1 << D) - 1); // a mod 2^D

    // a0 is one of 0, 1, ..., 2^(D-1)-1, 2^(D-1), 2^(D-1)+1, ..., 2^D-1
    a0 -%= (1 << (D - 1)) + 1;
    // now a0 is -2^(D-1)-1, -2^(D-1), ..., -2, -1, 0, ..., 2^(D-1)-2

    // Next, add 2^D to those a0 that are negative (seen as i32)
    a0 +%= @as(u32, @bitCast(@as(i32, @bitCast(a0)) >> 31)) & (1 << D);
    // now a0 is 2^(D-1)-1, 2^(D-1), ..., 2^D-2, 2^D-1, 0, ..., 2^(D-1)-2

    a0 -%= (1 << (D - 1)) - 1;
    // now a0 is 0, 1, 2, ..., 2^(D-1)-1, 2^(D-1), -2^(D-1)+1, ..., -1

    const a0_plus_q = Q +% a0;
    const a1 = (a -% a0) >> D;

    return .{ .a0_plus_q = a0_plus_q, .a1 = a1 };
}

/// Splits 0 ≤ a < q into a0 and a1 with a = a1*alpha + a0 with -alpha/2 < a0 ≤ alpha/2,
/// except when we would have a1 = (q-1)/alpha in which case a1=0 is taken
/// and -alpha/2 ≤ a0 < 0. Returns a0 + q. Note 0 ≤ a1 < (q-1)/alpha.
/// Recall alpha = 2*gamma2.
fn decompose(a: u32, comptime gamma2: u32) struct { a0_plus_q: u32, a1: u32 } {
    const alpha = 2 * gamma2;

    // a1 = ⌈a / 128⌉
    var a1 = (a + 127) >> 7;

    if (alpha == 523776) {
        // For ML-DSA-87: gamma2 = 261888, alpha = 523776
        // 1025/2^22 is close enough to 1/4092 so that a1 becomes a/alpha rounded down
        a1 = ((a1 * 1025 + (1 << 21)) >> 22);

        // For the corner-case a1 = (q-1)/alpha = 16, we have to set a1=0
        a1 &= 15;
    } else if (alpha == 190464) {
        // For ML-DSA-65: gamma2 = 95232, alpha = 190464
        // 11275/2^24 is close enough to 1/1488 so that a1 becomes a/alpha rounded down
        a1 = ((a1 * 11275) + (1 << 23)) >> 24;

        // For the corner-case a1 = (q-1)/alpha = 44, we have to set a1=0
        a1 ^= @as(u32, @bitCast(@as(i32, @bitCast(43 -% a1)) >> 31)) & a1;
    } else {
        @compileError("unsupported gamma2/alpha value");
    }

    var a0_plus_q = a -% a1 * alpha;

    // In the corner-case, when we set a1=0, we will incorrectly
    // have a0 > (q-1)/2 and we'll need to subtract q. As we
    // return a0 + q, that comes down to adding q if a0 < (q-1)/2.
    a0_plus_q +%= @as(u32, @bitCast(@as(i32, @bitCast(a0_plus_q -% (Q - 1) / 2)) >> 31)) & Q;

    return .{ .a0_plus_q = a0_plus_q, .a1 = a1 };
}

/// Creates a hint bit to help recover high bits after a small perturbation.
/// Given:
/// - z0: the modified low bits (r0 - f mod Q) where f is small
/// - r1: the original high bits
/// Returns 1 if a hint is needed, 0 otherwise.
///
/// This implements makeHint from FIPS 204. The hint helps recover r1 from
/// r' = r - f without knowing f explicitly.
fn makeHint(z0: u32, r1: u32, comptime gamma2: u32) u32 {
    // If -alpha/2 < r0 - f <= alpha/2, then r1*alpha + r0 - f is a valid
    // decomposition of r' with the restrictions of decompose() and so r'1 = r1.
    // So the hint should be 0. This is covered by the first two inequalities.
    // There is one other case: if r0 - f = -alpha/2, then r1*alpha + r0 - f is
    // also a valid decomposition if r1 = 0. In the other cases a one is carried
    // and the hint should be 1.

    const cond1 = @intFromBool(z0 <= gamma2);
    const cond2 = @intFromBool(z0 > Q - gamma2);
    const eq_gamma2 = @intFromBool(z0 == Q - gamma2);
    const r1_is_zero = @intFromBool(r1 == 0);
    const cond3 = eq_gamma2 & r1_is_zero;

    return 1 - (cond1 | cond2 | cond3);
}

/// Uses a hint to reconstruct high bits from a perturbed value.
/// Given:
/// - rp: the perturbed value (r' = r - f)
/// - hint: the hint bit from makeHint
/// Returns the reconstructed high bits r1.
///
/// This implements useHint from FIPS 204.
fn useHint(rp: u32, hint: u32, comptime gamma2: u32) u32 {
    const decomp = decompose(rp, gamma2);
    const rp0_plus_q = decomp.a0_plus_q;
    var rp1 = decomp.a1;

    if (hint == 0) {
        return rp1;
    }

    // Depending on gamma2, handle the adjustment differently
    if (gamma2 == 261888) {
        // ML-DSA-65 and ML-DSA-87: max r1 is 15
        if (rp0_plus_q > Q) {
            rp1 = (rp1 + 1) & 15;
        } else {
            rp1 = (rp1 -% 1) & 15;
        }
    } else if (gamma2 == 95232) {
        // ML-DSA-44: max r1 is 43
        if (rp0_plus_q > Q) {
            if (rp1 == 43) {
                rp1 = 0;
            } else {
                rp1 += 1;
            }
        } else {
            if (rp1 == 0) {
                rp1 = 43;
            } else {
                rp1 -= 1;
            }
        }
    } else {
        @compileError("unsupported gamma2 value");
    }

    return rp1;
}

/// Creates a hint polynomial for the difference between perturbed and original high bits.
/// Returns the number of hint bits set to 1 (the population count).
///
/// This is used during signature generation to create hints that help verification
/// recover the high bits without access to the secret.
fn polyMakeHint(p0: Poly, p1: Poly, comptime gamma2: u32) struct { hint: Poly, count: u32 } {
    var hint = Poly.zero;
    var count: u32 = 0;

    for (0..N) |i| {
        const h = makeHint(p0.cs[i], p1.cs[i], gamma2);
        hint.cs[i] = h;
        count += h;
    }

    return .{ .hint = hint, .count = count };
}

/// Applies hints to reconstruct high bits from a perturbed polynomial.
///
/// This is used during signature verification to recover the high bits
/// using the hints provided in the signature.
fn polyUseHint(q: Poly, hint: Poly, comptime gamma2: u32) Poly {
    var result = Poly.zero;

    for (0..N) |i| {
        result.cs[i] = useHint(q.cs[i], hint.cs[i], gamma2);
    }

    return result;
}

/// Pack polynomial with coefficients in [Q-eta, Q+eta] into bytes.
/// For eta=2: packs coefficients into 3 bits each (96 bytes total)
/// For eta=4: packs coefficients into 4 bits each (128 bytes total)
/// Assumes coefficients are not normalized, but in [q-η, q+η].
fn polyPackLeqEta(p: Poly, comptime eta: u8, buf: []u8) void {
    comptime {
        if (eta != 2 and eta != 4) {
            @compileError("eta must be 2 or 4");
        }
    }

    if (eta == 2) {
        // 3 bits per coefficient: pack 8 coefficients into 3 bytes
        var j: usize = 0;
        var i: usize = 0;
        while (i < buf.len) : (i += 3) {
            const c0 = Q + eta - p.cs[j];
            const c1 = Q + eta - p.cs[j + 1];
            const c2 = Q + eta - p.cs[j + 2];
            const c3 = Q + eta - p.cs[j + 3];
            const c4 = Q + eta - p.cs[j + 4];
            const c5 = Q + eta - p.cs[j + 5];
            const c6 = Q + eta - p.cs[j + 6];
            const c7 = Q + eta - p.cs[j + 7];

            buf[i] = @truncate(c0 | (c1 << 3) | (c2 << 6));
            buf[i + 1] = @truncate((c2 >> 2) | (c3 << 1) | (c4 << 4) | (c5 << 7));
            buf[i + 2] = @truncate((c5 >> 1) | (c6 << 2) | (c7 << 5));

            j += 8;
        }
    } else { // eta == 4
        // 4 bits per coefficient: pack 2 coefficients into 1 byte
        var j: usize = 0;
        for (0..buf.len) |i| {
            const c0 = Q + eta - p.cs[j];
            const c1 = Q + eta - p.cs[j + 1];
            buf[i] = @truncate(c0 | (c1 << 4));
            j += 2;
        }
    }
}

/// Unpack polynomial with coefficients in [Q-eta, Q+eta] from bytes.
/// Output coefficients will not be normalized, but in [q-η, q+η].
fn polyUnpackLeqEta(comptime eta: u8, buf: []const u8) Poly {
    comptime {
        if (eta != 2 and eta != 4) {
            @compileError("eta must be 2 or 4");
        }
    }

    var p = Poly.zero;

    if (eta == 2) {
        // 3 bits per coefficient: unpack 8 coefficients from 3 bytes
        var j: usize = 0;
        var i: usize = 0;
        while (i < buf.len) : (i += 3) {
            p.cs[j] = Q + eta - (buf[i] & 7);
            p.cs[j + 1] = Q + eta - ((buf[i] >> 3) & 7);
            p.cs[j + 2] = Q + eta - ((buf[i] >> 6) | ((buf[i + 1] << 2) & 7));
            p.cs[j + 3] = Q + eta - ((buf[i + 1] >> 1) & 7);
            p.cs[j + 4] = Q + eta - ((buf[i + 1] >> 4) & 7);
            p.cs[j + 5] = Q + eta - ((buf[i + 1] >> 7) | ((buf[i + 2] << 1) & 7));
            p.cs[j + 6] = Q + eta - ((buf[i + 2] >> 2) & 7);
            p.cs[j + 7] = Q + eta - ((buf[i + 2] >> 5) & 7);
            j += 8;
        }
    } else { // eta == 4
        // 4 bits per coefficient: unpack 2 coefficients from 1 byte
        var j: usize = 0;
        for (0..buf.len) |i| {
            p.cs[j] = Q + eta - (buf[i] & 15);
            p.cs[j + 1] = Q + eta - (buf[i] >> 4);
            j += 2;
        }
    }

    return p;
}

/// Pack polynomial with coefficients < 1024 (T1) into bytes.
/// Packs 10 bits per coefficient: 4 coefficients into 5 bytes.
/// Assumes coefficients are normalized.
fn polyPackT1(p: Poly, buf: []u8) void {
    var j: usize = 0;
    var i: usize = 0;
    while (i < buf.len) : (i += 5) {
        buf[i] = @truncate(p.cs[j]);
        buf[i + 1] = @truncate((p.cs[j] >> 8) | (p.cs[j + 1] << 2));
        buf[i + 2] = @truncate((p.cs[j + 1] >> 6) | (p.cs[j + 2] << 4));
        buf[i + 3] = @truncate((p.cs[j + 2] >> 4) | (p.cs[j + 3] << 6));
        buf[i + 4] = @truncate(p.cs[j + 3] >> 2);
        j += 4;
    }
}

/// Unpack polynomial with coefficients < 1024 (T1) from bytes.
/// Output coefficients will be normalized.
fn polyUnpackT1(buf: []const u8) Poly {
    var p = Poly.zero;
    var j: usize = 0;
    var i: usize = 0;
    while (i < buf.len) : (i += 5) {
        p.cs[j] = (@as(u32, buf[i]) | (@as(u32, buf[i + 1]) << 8)) & 0x3ff;
        p.cs[j + 1] = ((@as(u32, buf[i + 1]) >> 2) | (@as(u32, buf[i + 2]) << 6)) & 0x3ff;
        p.cs[j + 2] = ((@as(u32, buf[i + 2]) >> 4) | (@as(u32, buf[i + 3]) << 4)) & 0x3ff;
        p.cs[j + 3] = ((@as(u32, buf[i + 3]) >> 6) | (@as(u32, buf[i + 4]) << 2)) & 0x3ff;
        j += 4;
    }
    return p;
}

/// Pack polynomial with coefficients in (-2^(D-1), 2^(D-1)] (T0) into bytes.
/// Packs 13 bits per coefficient: 8 coefficients into 13 bytes.
/// Assumes coefficients are not normalized, but in (q-2^(D-1), q+2^(D-1)].
fn polyPackT0(p: Poly, buf: []u8) void {
    const bound = 1 << (D - 1);
    var j: usize = 0;
    var i: usize = 0;
    while (i < buf.len) : (i += 13) {
        const p0 = Q + bound - p.cs[j];
        const p1 = Q + bound - p.cs[j + 1];
        const p2 = Q + bound - p.cs[j + 2];
        const p3 = Q + bound - p.cs[j + 3];
        const p4 = Q + bound - p.cs[j + 4];
        const p5 = Q + bound - p.cs[j + 5];
        const p6 = Q + bound - p.cs[j + 6];
        const p7 = Q + bound - p.cs[j + 7];

        buf[i] = @truncate(p0 >> 0);
        buf[i + 1] = @truncate((p0 >> 8) | (p1 << 5));
        buf[i + 2] = @truncate(p1 >> 3);
        buf[i + 3] = @truncate((p1 >> 11) | (p2 << 2));
        buf[i + 4] = @truncate((p2 >> 6) | (p3 << 7));
        buf[i + 5] = @truncate(p3 >> 1);
        buf[i + 6] = @truncate((p3 >> 9) | (p4 << 4));
        buf[i + 7] = @truncate(p4 >> 4);
        buf[i + 8] = @truncate((p4 >> 12) | (p5 << 1));
        buf[i + 9] = @truncate((p5 >> 7) | (p6 << 6));
        buf[i + 10] = @truncate(p6 >> 2);
        buf[i + 11] = @truncate((p6 >> 10) | (p7 << 3));
        buf[i + 12] = @truncate(p7 >> 5);

        j += 8;
    }
}

/// Unpack polynomial with coefficients in (-2^(D-1), 2^(D-1)] (T0) from bytes.
/// Output coefficients will not be normalized, but in (-2^(D-1), 2^(D-1)].
fn polyUnpackT0(buf: []const u8) Poly {
    const bound = 1 << (D - 1);
    var p = Poly.zero;
    var j: usize = 0;
    var i: usize = 0;
    while (i < buf.len) : (i += 13) {
        p.cs[j] = Q + bound - ((@as(u32, buf[i]) | (@as(u32, buf[i + 1]) << 8)) & 0x1fff);
        p.cs[j + 1] = Q + bound - (((@as(u32, buf[i + 1]) >> 5) | (@as(u32, buf[i + 2]) << 3) | (@as(u32, buf[i + 3]) << 11)) & 0x1fff);
        p.cs[j + 2] = Q + bound - (((@as(u32, buf[i + 3]) >> 2) | (@as(u32, buf[i + 4]) << 6)) & 0x1fff);
        p.cs[j + 3] = Q + bound - (((@as(u32, buf[i + 4]) >> 7) | (@as(u32, buf[i + 5]) << 1) | (@as(u32, buf[i + 6]) << 9)) & 0x1fff);
        p.cs[j + 4] = Q + bound - (((@as(u32, buf[i + 6]) >> 4) | (@as(u32, buf[i + 7]) << 4) | (@as(u32, buf[i + 8]) << 12)) & 0x1fff);
        p.cs[j + 5] = Q + bound - (((@as(u32, buf[i + 8]) >> 1) | (@as(u32, buf[i + 9]) << 7)) & 0x1fff);
        p.cs[j + 6] = Q + bound - (((@as(u32, buf[i + 9]) >> 6) | (@as(u32, buf[i + 10]) << 2) | (@as(u32, buf[i + 11]) << 10)) & 0x1fff);
        p.cs[j + 7] = Q + bound - ((@as(u32, buf[i + 11]) >> 3) | (@as(u32, buf[i + 12]) << 5));
        j += 8;
    }
    return p;
}

/// Convert coefficient from centered representation to non-negative.
/// Transforms value from [0,γ₁] ∪ (Q-γ₁, Q) to [0, 2γ₁).
fn centeredToPositive(val: u32, comptime gamma1: u32) u32 {
    var result = gamma1 -% val;
    result +%= (signMask(u32, result) & Q);
    return result;
}

/// Pack polynomial with coefficients in (-gamma1, gamma1] into bytes.
/// For gamma1_bits=17: packs 18 bits per coefficient (4 coefficients into 9 bytes)
/// For gamma1_bits=19: packs 20 bits per coefficient (2 coefficients into 5 bytes)
/// Assumes coefficients are normalized.
fn polyPackLeGamma1(p: Poly, comptime gamma1_bits: u8, buf: []u8) void {
    const gamma1: u32 = @as(u32, 1) << gamma1_bits;

    if (gamma1_bits == 17) {
        // Pack 4 coefficients into 9 bytes (18 bits each)
        var j: usize = 0;
        var i: usize = 0;
        while (i < buf.len) : (i += 9) {
            // Convert from [0,γ₁] ∪ (Q-γ₁, Q) to [0, 2γ₁)
            const p0 = centeredToPositive(p.cs[j], gamma1);
            const p1 = centeredToPositive(p.cs[j + 1], gamma1);
            const p2 = centeredToPositive(p.cs[j + 2], gamma1);
            const p3 = centeredToPositive(p.cs[j + 3], gamma1);

            buf[i] = @truncate(p0);
            buf[i + 1] = @truncate(p0 >> 8);
            buf[i + 2] = @truncate((p0 >> 16) | (p1 << 2));
            buf[i + 3] = @truncate(p1 >> 6);
            buf[i + 4] = @truncate((p1 >> 14) | (p2 << 4));
            buf[i + 5] = @truncate(p2 >> 4);
            buf[i + 6] = @truncate((p2 >> 12) | (p3 << 6));
            buf[i + 7] = @truncate(p3 >> 2);
            buf[i + 8] = @truncate(p3 >> 10);

            j += 4;
        }
    } else if (gamma1_bits == 19) {
        // Pack 2 coefficients into 5 bytes (20 bits each)
        var j: usize = 0;
        var i: usize = 0;
        while (i < buf.len) : (i += 5) {
            const p0 = centeredToPositive(p.cs[j], gamma1);
            const p1 = centeredToPositive(p.cs[j + 1], gamma1);

            buf[i] = @truncate(p0);
            buf[i + 1] = @truncate(p0 >> 8);
            buf[i + 2] = @truncate((p0 >> 16) | (p1 << 4));
            buf[i + 3] = @truncate(p1 >> 4);
            buf[i + 4] = @truncate(p1 >> 12);

            j += 2;
        }
    } else {
        @compileError("gamma1_bits must be 17 or 19");
    }
}

/// Unpack polynomial with coefficients in (-gamma1, gamma1] from bytes.
/// Output coefficients will be normalized.
fn polyUnpackLeGamma1(comptime gamma1_bits: u8, buf: []const u8) Poly {
    const gamma1: u32 = @as(u32, 1) << gamma1_bits;
    var p = Poly.zero;

    if (gamma1_bits == 17) {
        // Unpack 4 coefficients from 9 bytes (18 bits each)
        var j: usize = 0;
        var i: usize = 0;
        while (i < buf.len) : (i += 9) {
            var p0 = @as(u32, buf[i]) | (@as(u32, buf[i + 1]) << 8) | ((@as(u32, buf[i + 2]) & 0x3) << 16);
            var p1 = (@as(u32, buf[i + 2]) >> 2) | (@as(u32, buf[i + 3]) << 6) | ((@as(u32, buf[i + 4]) & 0xf) << 14);
            var p2 = (@as(u32, buf[i + 4]) >> 4) | (@as(u32, buf[i + 5]) << 4) | ((@as(u32, buf[i + 6]) & 0x3f) << 12);
            var p3 = (@as(u32, buf[i + 6]) >> 6) | (@as(u32, buf[i + 7]) << 2) | (@as(u32, buf[i + 8]) << 10);

            // Convert from [0, 2γ₁) to (-γ₁, γ₁]
            p0 = centeredToPositive(p0, gamma1);
            p1 = centeredToPositive(p1, gamma1);
            p2 = centeredToPositive(p2, gamma1);
            p3 = centeredToPositive(p3, gamma1);

            p.cs[j] = p0;
            p.cs[j + 1] = p1;
            p.cs[j + 2] = p2;
            p.cs[j + 3] = p3;

            j += 4;
        }
    } else if (gamma1_bits == 19) {
        // Unpack 2 coefficients from 5 bytes (20 bits each)
        var j: usize = 0;
        var i: usize = 0;
        while (i < buf.len) : (i += 5) {
            var p0 = @as(u32, buf[i]) | (@as(u32, buf[i + 1]) << 8) | ((@as(u32, buf[i + 2]) & 0xf) << 16);
            var p1 = (@as(u32, buf[i + 2]) >> 4) | (@as(u32, buf[i + 3]) << 4) | (@as(u32, buf[i + 4]) << 12);

            p0 = centeredToPositive(p0, gamma1);
            p1 = centeredToPositive(p1, gamma1);

            p.cs[j] = p0;
            p.cs[j + 1] = p1;

            j += 2;
        }
    } else {
        @compileError("gamma1_bits must be 17 or 19");
    }

    return p;
}

/// Pack W1 polynomial for verification.
/// For gamma1_bits=17: packs 6 bits per coefficient (4 coefficients into 3 bytes)
/// For gamma1_bits=19: packs 4 bits per coefficient (2 coefficients into 1 byte)
/// Assumes coefficients are normalized.
fn polyPackW1(p: Poly, comptime gamma1_bits: u8, buf: []u8) void {
    if (gamma1_bits == 17) {
        // Pack 4 coefficients into 3 bytes (6 bits each)
        var j: usize = 0;
        var i: usize = 0;
        while (i < buf.len) : (i += 3) {
            buf[i] = @truncate(p.cs[j] | (p.cs[j + 1] << 6));
            buf[i + 1] = @truncate((p.cs[j + 1] >> 2) | (p.cs[j + 2] << 4));
            buf[i + 2] = @truncate((p.cs[j + 2] >> 4) | (p.cs[j + 3] << 2));
            j += 4;
        }
    } else if (gamma1_bits == 19) {
        // Pack 2 coefficients into 1 byte (4 bits each) - equivalent to packLe16
        var j: usize = 0;
        for (0..buf.len) |i| {
            buf[i] = @truncate(p.cs[j] | (p.cs[j + 1] << 4));
            j += 2;
        }
    } else {
        @compileError("gamma1_bits must be 17 or 19");
    }
}

fn polyDeriveUniform(seed: *const [32]u8, nonce: u16) Poly {
    var domain_sep: [2]u8 = undefined;
    domain_sep[0] = @truncate(nonce);
    domain_sep[1] = @truncate(nonce >> 8);

    return sampleUniformRejection(
        Poly,
        Q,
        23,
        N,
        seed,
        &domain_sep,
    );
}

/// Sample p uniformly with coefficients of norm less than or equal to η,
/// using the given seed and nonce with SHAKE-256.
/// The polynomial will not be normalized, but will have coefficients in [q-η, q+η].
/// FIPS 204: ExpandS (Algorithm 27)
fn expandS(comptime eta: u8, seed: *const [64]u8, nonce: u16) Poly {
    comptime {
        if (eta != 2 and eta != 4) {
            @compileError("eta must be 2 or 4");
        }
    }

    var p = Poly.zero;
    var i: usize = 0;

    var buf: [sha3.Shake256.block_length]u8 = undefined; // SHAKE-256 rate is 136 bytes

    // Prepare input: seed || nonce (little-endian u16)
    var input: [66]u8 = undefined;
    @memcpy(input[0..64], seed);
    input[64] = @truncate(nonce);
    input[65] = @truncate(nonce >> 8);

    var h = sha3.Shake256.init(.{});
    h.update(&input);

    while (i < N) {
        h.squeeze(&buf);

        // Process buffer: extract two samples per byte (4-bit nibbles)
        var j: usize = 0;
        while (j < buf.len and i < N) : (j += 1) {
            var t1 = @as(u32, buf[j]) & 15;
            var t2 = @as(u32, buf[j]) >> 4;

            if (eta == 2) {
                // For eta=2: reject if t > 14, then reduce mod 5
                if (t1 <= 14) {
                    t1 -%= ((205 * t1) >> 10) * 5; // reduce mod 5
                    p.cs[i] = Q + eta - t1;
                    i += 1;
                }
                if (t2 <= 14 and i < N) {
                    t2 -%= ((205 * t2) >> 10) * 5; // reduce mod 5
                    p.cs[i] = Q + eta - t2;
                    i += 1;
                }
            } else if (eta == 4) {
                // For eta=4: accept if t <= 2*eta = 8
                if (t1 <= 2 * eta) {
                    p.cs[i] = Q + eta - t1;
                    i += 1;
                }
                if (t2 <= 2 * eta and i < N) {
                    p.cs[i] = Q + eta - t2;
                    i += 1;
                }
            }
        }
    }

    return p;
}

/// Sample p uniformly with τ non-zero coefficients in {Q-1, 1} using SHAKE-256.
/// This creates a "ball" polynomial with exactly tau non-zero ±1 coefficients.
/// The polynomial will be normalized with coefficients in {0, 1, Q-1}.
/// FIPS 204: SampleInBall (Algorithm 18)
fn sampleInBall(comptime tau: u16, seed: []const u8) Poly {
    var p = Poly.zero;

    var buf: [sha3.Shake256.block_length]u8 = undefined; // SHAKE-256 rate is 136 bytes

    var h = sha3.Shake256.init(.{});
    h.update(seed);
    h.squeeze(&buf);

    // Extract signs from first 8 bytes
    var signs: u64 = 0;
    for (0..8) |j| {
        signs |= @as(u64, buf[j]) << @intCast(j * 8);
    }
    var buf_off: usize = 8;

    // Generate tau non-zero coefficients using Fisher-Yates shuffle
    // Start with N-tau zeros, then add tau ±1 values
    var i: u16 = N - tau;
    while (i < N) : (i += 1) {
        var b: u16 = undefined;

        // Find location using rejection sampling
        while (true) {
            if (buf_off >= buf.len) {
                h.squeeze(&buf);
                buf_off = 0;
            }

            b = buf[buf_off];
            buf_off += 1;

            if (b <= i) {
                break;
            }
        }

        // Shuffle: move existing value to position i
        p.cs[i] = p.cs[b];

        // Set position b to ±1 based on sign bit
        p.cs[b] = 1;
        const sign_bit: u1 = @truncate(signs);
        const mask = bitMask(u32, sign_bit);
        p.cs[b] ^= mask & (1 | (Q - 1));
        signs >>= 1;
    }

    return p;
}

/// Sample a polynomial with coefficients uniformly distributed in (-gamma1, gamma1]
/// Used for sampling the masking vector y during signing
/// FIPS 204: ExpandMask (Algorithm 28)
fn expandMask(comptime gamma1_bits: u8, seed: *const [64]u8, nonce: u16) Poly {
    const packed_size = ((gamma1_bits + 1) * N) / 8;
    var buf: [packed_size]u8 = undefined;

    // Construct IV: seed || nonce (little-endian)
    var iv: [66]u8 = undefined;
    @memcpy(iv[0..64], seed);
    iv[64] = @truncate(nonce & 0xFF);
    iv[65] = @truncate(nonce >> 8);

    var h = sha3.Shake256.init(.{});
    h.update(&iv);
    h.squeeze(&buf);

    // Unpack the polynomial
    return polyUnpackLeGamma1(gamma1_bits, &buf);
}

fn MLDSAImpl(comptime p: Params) type {
    return struct {
        pub const params = p;
        pub const name = p.name;
        pub const gamma1: u32 = @as(u32, 1) << p.gamma1_bits;
        pub const beta: u32 = p.tau * p.eta;
        pub const alpha: u32 = 2 * p.gamma2;

        const Self = @This();
        const PolyVecL = PolyVec(p.l);
        const PolyVecK = PolyVec(p.k);
        const MatKxL = Mat(p.k, p.l);

        /// Length of the seed used for deterministic key generation (32 bytes).
        pub const seed_length: usize = 32;

        /// Length (in bytes) of optional random bytes, for non-deterministic signatures.
        pub const noise_length = 32;

        /// Size of an encoded public key in bytes.
        pub const public_key_bytes: usize = 32 + polyT1PackedSize() * p.k;

        /// Size of an encoded secret key in bytes.
        pub const private_key_bytes: usize = 32 + 32 + p.tr_size +
            polyLeqEtaPackedSize() * (p.l + p.k) + polyT0PackedSize() * p.k;

        /// Size of an encoded signature in bytes.
        pub const signature_bytes: usize = p.ctilde_size +
            polyLeGamma1PackedSize() * p.l + p.omega + p.k;

        // Packed sizes for different polynomial representations
        fn polyLeqEtaPackedSize() usize {
            // For eta=2: 3 bits per coefficient (values in [0,4])
            // For eta=4: 4 bits per coefficient (values in [0,8])
            const double_eta_bits = if (p.eta == 2) 3 else 4;
            return (N * double_eta_bits) / 8;
        }

        fn polyLeGamma1PackedSize() usize {
            return ((p.gamma1_bits + 1) * N) / 8;
        }

        fn polyT1PackedSize() usize {
            return (N * (Q_BITS - D)) / 8;
        }

        fn polyT0PackedSize() usize {
            return (N * D) / 8;
        }

        fn polyW1PackedSize() usize {
            return (N * (Q_BITS - p.gamma1_bits)) / 8;
        }

        /// Helper function to compute CRH (Collision Resistant Hash) using SHAKE-256.
        /// This consolidates the repeated pattern of init-update-squeeze for hash operations.
        fn crh(comptime outsize: usize, inputs: anytype) [outsize]u8 {
            var h = sha3.Shake256.init(.{});
            inline for (inputs) |input| {
                h.update(input);
            }
            var out: [outsize]u8 = undefined;
            h.squeeze(&out);
            return out;
        }

        /// Helper function to compute t = As1 + s2.
        /// This is used during key generation and public key reconstruction.
        fn computeT(A: MatKxL, s1_hat: PolyVecL, s2: PolyVecK) PolyVecK {
            const t = A.mulVec(s1_hat).add(s2);
            return t.normalize();
        }

        /// ML-DSA public key
        pub const PublicKey = struct {
            /// Size of the encoded public key in bytes
            pub const encoded_length: usize = 32 + polyT1PackedSize() * p.k;

            rho: [32]u8, // Seed for matrix A
            t1: PolyVecK, // High bits of t = As1 + s2

            // Cached values
            t1_packed: [polyT1PackedSize() * p.k]u8,
            A: MatKxL,
            tr: [p.tr_size]u8, // CRH(rho || t1)

            /// Encode public key to bytes
            pub fn toBytes(self: PublicKey) [encoded_length]u8 {
                var out: [encoded_length]u8 = undefined;
                @memcpy(out[0..32], &self.rho);
                @memcpy(out[32..], &self.t1_packed);
                return out;
            }

            /// Decode public key from bytes
            pub fn fromBytes(bytes: [encoded_length]u8) !PublicKey {
                var pk: PublicKey = undefined;
                @memcpy(&pk.rho, bytes[0..32]);
                @memcpy(&pk.t1_packed, bytes[32..]);

                pk.t1 = PolyVecK.unpackT1(pk.t1_packed[0..]);
                pk.A = MatKxL.derive(&pk.rho);
                pk.tr = crh(p.tr_size, .{&bytes});

                return pk;
            }
        };

        /// ML-DSA secret key
        pub const SecretKey = struct {
            /// Size of the encoded secret key in bytes
            pub const encoded_length: usize = 32 + 32 + p.tr_size +
                polyLeqEtaPackedSize() * (p.l + p.k) + polyT0PackedSize() * p.k;

            rho: [32]u8, // Seed for matrix A
            key: [32]u8, // Seed for signature generation randomness
            tr: [p.tr_size]u8, // CRH(rho || t1)
            s1: PolyVecL, // Secret vector 1
            s2: PolyVecK, // Secret vector 2
            t0: PolyVecK, // Low bits of t = As1 + s2

            // Cached values (in NTT domain)
            A: MatKxL,
            s1_hat: PolyVecL,
            s2_hat: PolyVecK,
            t0_hat: PolyVecK,

            /// Encode secret key to bytes
            pub fn toBytes(self: SecretKey) [encoded_length]u8 {
                var out: [encoded_length]u8 = undefined;
                var offset: usize = 0;

                @memcpy(out[offset .. offset + 32], &self.rho);
                offset += 32;

                @memcpy(out[offset .. offset + 32], &self.key);
                offset += 32;

                @memcpy(out[offset .. offset + p.tr_size], &self.tr);
                offset += p.tr_size;

                if (p.eta == 2) {
                    self.s1.packLeqEta(2, out[offset..][0 .. p.l * polyLeqEtaPackedSize()]);
                } else {
                    self.s1.packLeqEta(4, out[offset..][0 .. p.l * polyLeqEtaPackedSize()]);
                }
                offset += p.l * polyLeqEtaPackedSize();

                if (p.eta == 2) {
                    self.s2.packLeqEta(2, out[offset..][0 .. p.k * polyLeqEtaPackedSize()]);
                } else {
                    self.s2.packLeqEta(4, out[offset..][0 .. p.k * polyLeqEtaPackedSize()]);
                }
                offset += p.k * polyLeqEtaPackedSize();

                self.t0.packT0(out[offset..][0 .. p.k * polyT0PackedSize()]);
                offset += p.k * polyT0PackedSize();

                return out;
            }

            /// Decode secret key from bytes
            pub fn fromBytes(bytes: [encoded_length]u8) !SecretKey {
                var sk: SecretKey = undefined;
                var offset: usize = 0;

                @memcpy(&sk.rho, bytes[offset .. offset + 32]);
                offset += 32;

                @memcpy(&sk.key, bytes[offset .. offset + 32]);
                offset += 32;

                @memcpy(&sk.tr, bytes[offset .. offset + p.tr_size]);
                offset += p.tr_size;

                sk.s1 = if (p.eta == 2)
                    PolyVecL.unpackLeqEta(2, bytes[offset..][0 .. p.l * polyLeqEtaPackedSize()])
                else
                    PolyVecL.unpackLeqEta(4, bytes[offset..][0 .. p.l * polyLeqEtaPackedSize()]);
                offset += p.l * polyLeqEtaPackedSize();

                sk.s2 = if (p.eta == 2)
                    PolyVecK.unpackLeqEta(2, bytes[offset..][0 .. p.k * polyLeqEtaPackedSize()])
                else
                    PolyVecK.unpackLeqEta(4, bytes[offset..][0 .. p.k * polyLeqEtaPackedSize()]);
                offset += p.k * polyLeqEtaPackedSize();

                sk.t0 = PolyVecK.unpackT0(bytes[offset..][0 .. p.k * polyT0PackedSize()]);
                offset += p.k * polyT0PackedSize();

                // Compute cached NTT values for efficient signing
                sk.A = MatKxL.derive(&sk.rho);
                sk.s1_hat = sk.s1.ntt();
                sk.s2_hat = sk.s2.ntt();
                sk.t0_hat = sk.t0.ntt();

                return sk;
            }

            /// Compute the public key from this private key
            pub fn public(self: *const SecretKey) PublicKey {
                var pk: PublicKey = undefined;
                pk.rho = self.rho;
                pk.A = self.A;
                pk.tr = self.tr;

                // Reconstruct t = As1 + s2, then extract high bits t1
                // Using power2Round: t = t1 * 2^D + t0
                const t = computeT(self.A, self.s1_hat, self.s2);

                var t0_unused: PolyVecK = undefined;
                pk.t1 = t.power2Round(&t0_unused);
                pk.t1.packT1(&pk.t1_packed);

                return pk;
            }

            /// Create a Signer for incrementally signing a message.
            /// The noise parameter can be null for deterministic signatures,
            /// or provide randomness for hedged signatures (recommended for fault attack resistance).
            pub fn signer(self: *const SecretKey, noise: ?[noise_length]u8) !Signer {
                return self.signerWithContext(noise, "");
            }

            /// Create a Signer for incrementally signing a message with context.
            /// The noise parameter can be null for deterministic signatures,
            /// or provide randomness for hedged signatures (recommended for fault attack resistance).
            /// The context parameter is an optional context string (max 255 bytes).
            pub fn signerWithContext(self: *const SecretKey, noise: ?[noise_length]u8, context: []const u8) ContextTooLongError!Signer {
                return Signer.init(self, noise, context);
            }
        };

        /// Generate a new key pair from a seed (deterministic)
        pub fn newKeyFromSeed(seed: *const [seed_length]u8) struct { pk: PublicKey, sk: SecretKey } {
            var sk: SecretKey = undefined;
            var pk: PublicKey = undefined;

            // NIST mode: expand seed || k || l using SHAKE-256 to get 128-byte expanded seed
            const e_seed = crh(128, .{ seed, &[_]u8{ p.k, p.l } });

            @memcpy(&pk.rho, e_seed[0..32]);
            const s_seed = e_seed[32..96];
            @memcpy(&sk.key, e_seed[96..128]);
            @memcpy(&sk.rho, &pk.rho);

            sk.A = MatKxL.derive(&pk.rho);
            pk.A = sk.A;

            const s_seed_array: *const [64]u8 = s_seed[0..64];
            for (0..p.l) |i| {
                sk.s1.ps[i] = expandS(p.eta, s_seed_array, @intCast(i));
            }

            for (0..p.k) |i| {
                sk.s2.ps[i] = expandS(p.eta, s_seed_array, @intCast(p.l + i));
            }

            sk.s1_hat = sk.s1.ntt();
            sk.s2_hat = sk.s2.ntt();

            const t = computeT(sk.A, sk.s1_hat, sk.s2);

            pk.t1 = t.power2Round(&sk.t0);
            sk.t0_hat = sk.t0.ntt();
            pk.t1.packT1(&pk.t1_packed);

            // tr = H(pk) = H(rho || t1)
            const pk_bytes = pk.toBytes();
            const tr = crh(p.tr_size, .{&pk_bytes});
            sk.tr = tr;
            pk.tr = tr;

            return .{ .pk = pk, .sk = sk };
        }

        /// ML-DSA signature
        pub const Signature = struct {
            /// Size of the encoded signature in bytes
            pub const encoded_length: usize = p.ctilde_size +
                polyLeGamma1PackedSize() * p.l + p.omega + p.k;

            c_tilde: [p.ctilde_size]u8, // Challenge hash
            z: PolyVecL, // Response vector
            hint: PolyVecK, // Hint vector

            /// Encode signature to bytes
            pub fn toBytes(self: Signature) [encoded_length]u8 {
                var out: [encoded_length]u8 = undefined;
                var offset: usize = 0;

                @memcpy(out[offset .. offset + p.ctilde_size], &self.c_tilde);
                offset += p.ctilde_size;

                self.z.packLeGamma1(p.gamma1_bits, out[offset .. offset + polyLeGamma1PackedSize() * p.l]);
                offset += polyLeGamma1PackedSize() * p.l;

                _ = self.hint.packHint(p.omega, out[offset..]);

                return out;
            }

            /// Decode signature from bytes
            pub fn fromBytes(bytes: [encoded_length]u8) EncodingError!Signature {
                var sig: Signature = undefined;
                var offset: usize = 0;

                @memcpy(&sig.c_tilde, bytes[offset .. offset + p.ctilde_size]);
                offset += p.ctilde_size;

                sig.z = PolyVecL.unpackLeGamma1(p.gamma1_bits, bytes[offset .. offset + polyLeGamma1PackedSize() * p.l]);
                offset += polyLeGamma1PackedSize() * p.l;

                // Validate ||z||_inf < gamma1 - beta per FIPS 204
                if (sig.z.exceeds(gamma1 - beta)) {
                    return error.InvalidEncoding;
                }

                sig.hint = PolyVecK.unpackHint(p.omega, bytes[offset..]) orelse return error.InvalidEncoding;

                return sig;
            }

            pub const VerifyError = Verifier.InitError || Verifier.VerifyError;

            /// Verify this signature against a message and public key.
            /// Returns an error if the signature is invalid.
            pub fn verify(
                sig: Signature,
                msg: []const u8,
                public_key: PublicKey,
            ) VerifyError!void {
                return sig.verifyWithContext(msg, public_key, "");
            }

            /// Verify this signature against a message and public key with context.
            /// Returns an error if the signature is invalid.
            /// The context parameter is an optional context string (max 255 bytes).
            pub fn verifyWithContext(
                sig: Signature,
                msg: []const u8,
                public_key: PublicKey,
                context: []const u8,
            ) VerifyError!void {
                if (context.len > 255) {
                    return error.SignatureVerificationFailed;
                }

                var h = sha3.Shake256.init(.{});
                h.update(&public_key.tr);
                h.update(&[_]u8{0}); // Domain separator: 0 for pure ML-DSA
                h.update(&[_]u8{@intCast(context.len)});
                if (context.len > 0) {
                    h.update(context);
                }
                h.update(msg);
                var mu: [64]u8 = undefined;
                h.squeeze(&mu);

                const z_hat = sig.z.ntt();
                const Az = public_key.A.mulVecHat(z_hat);

                // Compute w' ≈ Az - 2^d·c·t1 (approximate w used in signing)
                var Az2dct1 = public_key.t1.mulBy2toD();
                Az2dct1 = Az2dct1.ntt();
                const c_poly = sampleInBall(p.tau, &sig.c_tilde);
                const c_hat = c_poly.ntt();
                for (0..p.k) |i| {
                    Az2dct1.ps[i] = Az2dct1.ps[i].mulHat(c_hat);
                }
                Az2dct1 = Az.sub(Az2dct1);
                Az2dct1 = Az2dct1.reduceLe2Q();
                Az2dct1 = Az2dct1.invNTT();
                Az2dct1 = Az2dct1.normalizeAssumingLe2Q();

                // Apply hints to recover high bits w1'
                var w1_prime = Az2dct1.useHint(sig.hint, p.gamma2);
                var w1_packed: [polyW1PackedSize() * p.k]u8 = undefined;
                w1_prime.packW1(p.gamma1_bits, &w1_packed);

                const c_prime = crh(p.ctilde_size, .{ &mu, &w1_packed });

                if (!mem.eql(u8, &c_prime, &sig.c_tilde)) {
                    return error.SignatureVerificationFailed;
                }
            }

            /// Create a Verifier for incrementally verifying a signature.
            pub fn verifier(self: Signature, public_key: PublicKey) !Verifier {
                return self.verifierWithContext(public_key, "");
            }

            /// Create a Verifier for incrementally verifying a signature with context.
            /// The context parameter is an optional context string (max 255 bytes).
            pub fn verifierWithContext(self: Signature, public_key: PublicKey, context: []const u8) ContextTooLongError!Verifier {
                return Verifier.init(self, public_key, context);
            }
        };

        /// A Signer is used to incrementally compute a signature over a streamed message.
        /// It can be obtained from a `SecretKey` or `KeyPair`, using the `signer()` function.
        pub const Signer = struct {
            h: sha3.Shake256, // For computing μ = CRH(tr || msg)
            secret_key: *const SecretKey,
            rnd: [32]u8,

            /// Initialize a new Signer.
            /// The noise parameter can be null for deterministic signatures,
            /// or provide randomness for hedged signatures (recommended for fault attack resistance).
            /// The context parameter is an optional context string (max 255 bytes).
            pub fn init(secret_key: *const SecretKey, noise: ?[noise_length]u8, context: []const u8) ContextTooLongError!Signer {
                if (context.len > 255) {
                    return error.ContextTooLong;
                }

                var h = sha3.Shake256.init(.{});
                h.update(&secret_key.tr);
                h.update(&[_]u8{0}); // Domain separator: 0 for pure ML-DSA
                h.update(&[_]u8{@intCast(context.len)});
                if (context.len > 0) {
                    h.update(context);
                }

                return Signer{
                    .h = h,
                    .secret_key = secret_key,
                    .rnd = noise orelse .{0} ** 32,
                };
            }

            /// Add new data to the message being signed.
            pub fn update(self: *Signer, data: []const u8) void {
                self.h.update(data);
            }

            /// Compute a signature over the entire message.
            pub fn finalize(self: *Signer) Signature {
                var mu: [64]u8 = undefined;
                self.h.squeeze(&mu);

                const rho_prime = crh(64, .{ &self.secret_key.key, &self.rnd, &mu });

                var sig: Signature = undefined;
                var y_nonce: u16 = 0;

                // Rejection sampling loop (FIPS 204 Algorithm 2, steps 5-16)
                var attempt: u32 = 0;
                while (true) {
                    attempt += 1;
                    if (attempt >= 576) { // (6/7)⁵⁷⁶ < 2⁻¹²⁸
                        @branchHint(.unlikely);
                        unreachable;
                    }

                    const y = PolyVecL.deriveUniformLeGamma1(p.gamma1_bits, &rho_prime, y_nonce);
                    y_nonce += @intCast(p.l);

                    const y_hat = y.ntt();
                    var w = self.secret_key.A.mulVec(y_hat);

                    w = w.normalize();
                    var w0: PolyVecK = undefined;
                    const w1 = w.decomposeVec(p.gamma2, &w0);
                    var w1_packed: [polyW1PackedSize() * p.k]u8 = undefined;
                    w1.packW1(p.gamma1_bits, &w1_packed);

                    sig.c_tilde = crh(p.ctilde_size, .{ &mu, &w1_packed });

                    const c_poly = sampleInBall(p.tau, &sig.c_tilde);
                    const c_hat = c_poly.ntt();

                    // Rejection check: ensure masking is effective
                    var w0mcs2: PolyVecK = undefined;
                    for (0..p.k) |i| {
                        w0mcs2.ps[i] = c_hat.mulHat(self.secret_key.s2_hat.ps[i]);
                        w0mcs2.ps[i] = w0mcs2.ps[i].invNTT();
                    }
                    w0mcs2 = w0.sub(w0mcs2);
                    w0mcs2 = w0mcs2.normalize();

                    if (w0mcs2.exceeds(p.gamma2 - beta)) {
                        continue;
                    }

                    // Compute response z = y + c·s1
                    for (0..p.l) |i| {
                        sig.z.ps[i] = c_hat.mulHat(self.secret_key.s1_hat.ps[i]);
                        sig.z.ps[i] = sig.z.ps[i].invNTT();
                    }
                    sig.z = sig.z.add(y);
                    sig.z = sig.z.normalize();

                    if (sig.z.exceeds(gamma1 - beta)) {
                        continue;
                    }

                    var ct0: PolyVecK = undefined;
                    for (0..p.k) |i| {
                        ct0.ps[i] = c_hat.mulHat(self.secret_key.t0_hat.ps[i]);
                        ct0.ps[i] = ct0.ps[i].invNTT();
                    }
                    ct0 = ct0.reduceLe2Q();
                    ct0 = ct0.normalize();

                    if (ct0.exceeds(p.gamma2)) {
                        continue;
                    }

                    // Generate hints for verification
                    var w0mcs2pct0 = w0mcs2.add(ct0);
                    w0mcs2pct0 = w0mcs2pct0.reduceLe2Q();
                    w0mcs2pct0 = w0mcs2pct0.normalizeAssumingLe2Q();
                    const hint_result = PolyVecK.makeHintVec(w0mcs2pct0, w1, p.gamma2);
                    if (hint_result.pop > p.omega) {
                        continue;
                    }
                    sig.hint = hint_result.hint;

                    return sig;
                }
            }
        };

        /// A Verifier is used to incrementally verify a signature over a streamed message.
        /// It can be obtained from a `Signature`, using the `verifier()` function.
        pub const Verifier = struct {
            h: sha3.Shake256, // For computing μ = CRH(tr || msg)
            signature: Signature,
            public_key: PublicKey,

            pub const InitError = EncodingError;
            pub const VerifyError = SignatureVerificationError;

            /// Initialize a new Verifier.
            /// The context parameter is an optional context string (max 255 bytes).
            pub fn init(signature: Signature, public_key: PublicKey, context: []const u8) ContextTooLongError!Verifier {
                if (context.len > 255) {
                    return error.ContextTooLong;
                }

                var h = sha3.Shake256.init(.{});
                h.update(&public_key.tr);
                h.update(&[_]u8{0}); // Domain separator: 0 for pure ML-DSA
                h.update(&[_]u8{@intCast(context.len)}); // Context length
                if (context.len > 0) {
                    h.update(context);
                }

                return Verifier{
                    .h = h,
                    .signature = signature,
                    .public_key = public_key,
                };
            }

            /// Add new content to the message to be verified.
            pub fn update(self: *Verifier, data: []const u8) void {
                self.h.update(data);
            }

            /// Verify that the signature is valid for the entire message.
            pub fn verify(self: *Verifier) SignatureVerificationError!void {
                var mu: [64]u8 = undefined;
                self.h.squeeze(&mu);

                const z_hat = self.signature.z.ntt();
                const Az = self.public_key.A.mulVecHat(z_hat);

                // Compute w' ≈ Az - 2^d·c·t1 (approximate w used in signing)
                var Az2dct1 = self.public_key.t1.mulBy2toD();
                Az2dct1 = Az2dct1.ntt();
                const c_poly = sampleInBall(p.tau, &self.signature.c_tilde);
                const c_hat = c_poly.ntt();
                for (0..p.k) |i| {
                    Az2dct1.ps[i] = Az2dct1.ps[i].mulHat(c_hat);
                }
                Az2dct1 = Az.sub(Az2dct1);
                Az2dct1 = Az2dct1.reduceLe2Q();
                Az2dct1 = Az2dct1.invNTT();
                Az2dct1 = Az2dct1.normalizeAssumingLe2Q();

                // Apply hints to recover high bits w1'
                var w1_prime = Az2dct1.useHint(self.signature.hint, p.gamma2);
                var w1_packed: [polyW1PackedSize() * p.k]u8 = undefined;
                w1_prime.packW1(p.gamma1_bits, &w1_packed);

                const c_prime = crh(p.ctilde_size, .{ &mu, &w1_packed });

                if (!mem.eql(u8, &c_prime, &self.signature.c_tilde)) {
                    return error.SignatureVerificationFailed;
                }
            }
        };

        /// A key pair consisting of a secret key and its corresponding public key.
        pub const KeyPair = struct {
            /// Length (in bytes) of a seed required to create a key pair.
            pub const seed_length = Self.seed_length;

            /// The public key component.
            public_key: PublicKey,

            /// The secret key component.
            secret_key: SecretKey,

            /// Generate a new random key pair.
            /// This uses the system's cryptographically secure random number generator.
            ///
            /// `crypto.random.bytes` must be supported by the target.
            pub fn generate() KeyPair {
                var seed: [Self.seed_length]u8 = undefined;
                crypto.random.bytes(&seed);
                return generateDeterministic(seed) catch unreachable;
            }

            /// Generate a key pair deterministically from a seed.
            /// Use for testing or when reproducibility is required.
            /// The seed should be generated using a cryptographically secure random source.
            pub fn generateDeterministic(seed: [32]u8) !KeyPair {
                const keys = newKeyFromSeed(&seed);
                return .{
                    .public_key = keys.pk,
                    .secret_key = keys.sk,
                };
            }

            /// Derive the public key from an existing secret key.
            /// This recomputes the public key components from the secret key.
            pub fn fromSecretKey(sk: SecretKey) !KeyPair {
                var pk: PublicKey = undefined;
                pk.rho = sk.rho;
                pk.tr = sk.tr;
                pk.A = sk.A;

                const t = computeT(sk.A, sk.s1_hat, sk.s2);

                var t0: PolyVecK = undefined;
                pk.t1 = t.power2Round(&t0);
                pk.t1.packT1(&pk.t1_packed);

                return .{
                    .public_key = pk,
                    .secret_key = sk,
                };
            }

            /// Create a Signer for incrementally signing a message.
            /// The noise parameter can be null for deterministic signatures,
            /// or provide randomness for hedged signatures (recommended for fault attack resistance).
            pub fn signer(self: *const KeyPair, noise: ?[noise_length]u8) !Signer {
                return self.secret_key.signer(noise);
            }

            /// Create a Signer for incrementally signing a message with context.
            /// The noise parameter can be null for deterministic signatures,
            /// or provide randomness for hedged signatures (recommended for fault attack resistance).
            /// The context parameter is an optional context string (max 255 bytes).
            pub fn signerWithContext(self: *const KeyPair, noise: ?[noise_length]u8, context: []const u8) ContextTooLongError!Signer {
                return self.secret_key.signerWithContext(noise, context);
            }

            /// Sign a message using this key pair.
            /// The noise parameter can be null for deterministic signatures,
            /// or provide randomness for hedged signatures (recommended for fault attack resistance).
            pub fn sign(
                kp: KeyPair,
                msg: []const u8,
                noise: ?[noise_length]u8,
            ) !Signature {
                return kp.signWithContext(msg, noise, "");
            }

            /// Sign a message using this key pair with context.
            /// The noise parameter can be null for deterministic signatures,
            /// or provide randomness for hedged signatures (recommended for fault attack resistance).
            /// The context parameter is an optional context string (max 255 bytes).
            pub fn signWithContext(
                kp: KeyPair,
                msg: []const u8,
                noise: ?[noise_length]u8,
                context: []const u8,
            ) ContextTooLongError!Signature {
                var st = try kp.signerWithContext(noise, context);
                st.update(msg);
                return st.finalize();
            }
        };
    };
}

test "modular arithmetic" {
    // Test Montgomery reduction
    const x: u64 = 12345678;
    const y = montReduceLe2Q(x);
    try testing.expect(y < 2 * Q);

    // Test modQ
    try testing.expectEqual(@as(u32, 0), modQ(Q));
    try testing.expectEqual(@as(u32, 1), modQ(Q + 1));
}

test "polynomial operations" {
    var p1 = Poly.zero;
    p1.cs[0] = 1;
    p1.cs[1] = 2;

    var p2 = Poly.zero;
    p2.cs[0] = 3;
    p2.cs[1] = 4;

    const p3 = p1.add(p2);
    try testing.expectEqual(@as(u32, 4), p3.cs[0]);
    try testing.expectEqual(@as(u32, 6), p3.cs[1]);
}

test "NTT and inverse NTT" {
    // Create a test polynomial in REGULAR FORM (not Montgomery)
    var p = Poly.zero;
    for (0..N) |i| {
        p.cs[i] = @intCast(i % Q);
    }

    // Apply NTT then inverse NTT
    // According to Dilithium spec: NTT followed by invNTT multiplies by R
    // So result will be p * R (i.e., p in Montgomery form)
    var p_ntt = p.ntt();

    // Reduce before invNTT (as Go test does)
    p_ntt = p_ntt.reduceLe2Q();

    const p_restored = p_ntt.invNTT();

    // Reduce and normalize
    const p_reduced = p_restored.reduceLe2Q();
    const p_norm = p_reduced.normalize();

    // Check if we get p * R (which equals toMont(p))
    for (0..N) |i| {
        const original: u32 = @intCast(i % Q);
        const expected = toMont(original);
        const expected_norm = modQ(expected);
        try testing.expectEqual(expected_norm, p_norm.cs[i]);
    }
}

test "parameter set instantiation" {
    // Just verify we can instantiate all three parameter sets
    const ml44 = MLDSA44;
    const ml65 = MLDSA65;
    const ml87 = MLDSA87;

    try testing.expectEqualStrings("ML-DSA-44", ml44.name);
    try testing.expectEqualStrings("ML-DSA-65", ml65.name);
    try testing.expectEqualStrings("ML-DSA-87", ml87.name);
}

test "compare zetas with Go implementation" {
    // First 16 zetas from Go implementation (in Montgomery form)
    const go_zetas = [16]u32{
        4193792, 25847,   5771523, 7861508, 237124,  7602457, 7504169,
        466468,  1826347, 2353451, 8021166, 6288512, 3119733, 5495562,
        3111497, 2680103,
    };

    // Compare our computed zetas with Go's
    for (0..16) |i| {
        try testing.expectEqual(go_zetas[i], zetas[i]);
    }
}

test "NTT with simple polynomial" {
    // Test with a very simple polynomial: just one coefficient set to 1 in regular form
    var p = Poly.zero;
    p.cs[0] = 1;

    var p_ntt = p.ntt();

    // Reduce before invNTT (as Go test does)
    p_ntt = p_ntt.reduceLe2Q();

    const p_restored = p_ntt.invNTT();

    // Result should be 1 * R = toMont(1) in Montgomery form
    const p_reduced = p_restored.reduceLe2Q();
    const p_norm = p_reduced.normalize();

    const expected = modQ(toMont(1));
    try testing.expectEqual(expected, p_norm.cs[0]);

    // All other coefficients should be 0 * R = 0
    for (1..N) |i| {
        try testing.expectEqual(@as(u32, 0), p_norm.cs[i]);
    }
}

test "Montgomery reduction correctness" {
    // Test that Montgomery reduction works correctly
    // montReduceLe2Q(a * b * R) = a * b mod q (where a, b are in Montgomery form)

    const x: u32 = 12345;
    const y: u32 = 67890;

    // Convert to Montgomery form
    const x_mont = toMont(x);
    const y_mont = toMont(y);

    // Multiply in Montgomery form
    const product_mont = montReduceLe2Q(@as(u64, x_mont) * @as(u64, y_mont));

    // Convert back from Montgomery form
    const product = montReduceLe2Q(@as(u64, product_mont));

    // Direct multiplication mod q
    const expected = modQ(@as(u32, @intCast((@as(u64, x) * @as(u64, y)) % Q)));

    try testing.expectEqual(expected, modQ(product));
}

// Removed debug test - was causing noise in output

test "compare inv_zetas with Go implementation" {
    // First 16 inv_zetas from Go implementation
    const go_inv_zetas = [16]u32{
        6403635, 846154,  6979993, 4442679, 1362209, 48306,   4460757,
        554416,  3545687, 6767575, 976891,  8196974, 2286327, 420899,
        2235985, 2939036,
    };

    // Compare our computed inv_zetas with Go's
    for (0..16) |i| {
        if (inv_zetas[i] != go_inv_zetas[i]) {
            std.debug.print("Mismatch at inv_zetas[{d}]: got {d}, expected {d}\n", .{ i, inv_zetas[i], go_inv_zetas[i] });
        }
        try testing.expectEqual(go_inv_zetas[i], inv_zetas[i]);
    }
}

test "power2Round correctness" {
    // Test that power2Round correctly splits values
    // For all a in [0, Q), we should have a = a1*2^D + a0
    // where -2^(D-1) < a0 <= 2^(D-1)

    // Test a few specific values
    const test_values = [_]u32{ 0, 1, Q / 2, Q - 1, 12345, 8380416 };

    for (test_values) |a| {
        if (a >= Q) continue;

        const result = power2Round(a);
        const a0 = @as(i32, @bitCast(result.a0_plus_q -% Q));
        const a1 = result.a1;

        // Check reconstruction: a = a1*2^D + a0
        const reconstructed = @as(i32, @bitCast(a1 << D)) + a0;
        try testing.expectEqual(@as(i32, @bitCast(a)), reconstructed);

        // Check a0 bounds: -2^(D-1) < a0 <= 2^(D-1)
        const bound: i32 = 1 << (D - 1);
        try testing.expect(a0 > -bound and a0 <= bound);
    }
}

test "decompose correctness for ML-DSA-65" {
    // Test decompose with gamma2 = 95232 (ML-DSA-44)
    const gamma2 = 95232;
    const alpha = 2 * gamma2;

    const test_values = [_]u32{ 0, 1, Q / 2, Q - 1, 12345 };

    for (test_values) |a| {
        if (a >= Q) continue;

        const result = decompose(a, gamma2);
        const a0 = @as(i32, @bitCast(result.a0_plus_q -% Q));
        const a1 = result.a1;

        // Check reconstruction: a = a1*alpha + a0 (mod Q)
        var reconstructed: i64 = @as(i64, @intCast(a1)) * @as(i64, @intCast(alpha)) + @as(i64, a0);
        reconstructed = @mod(reconstructed, @as(i64, Q));
        try testing.expectEqual(@as(i64, @intCast(a)), reconstructed);

        // Check a0 bounds (approximately)
        const bound: i32 = @intCast(alpha / 2);
        try testing.expect(@abs(a0) <= bound);
    }
}

test "decompose correctness for ML-DSA-87" {
    // Test decompose with gamma2 = 261888 (ML-DSA-65 and ML-DSA-87)
    const gamma2 = 261888;
    const alpha = 2 * gamma2;

    const test_values = [_]u32{ 0, 1, Q / 2, Q - 1, 12345 };

    for (test_values) |a| {
        if (a >= Q) continue;

        const result = decompose(a, gamma2);
        const a0 = @as(i32, @bitCast(result.a0_plus_q -% Q));
        const a1 = result.a1;

        // Check reconstruction: a = a1*alpha + a0 (mod Q)
        var reconstructed: i64 = @as(i64, @intCast(a1)) * @as(i64, @intCast(alpha)) + @as(i64, a0);
        reconstructed = @mod(reconstructed, @as(i64, Q));
        try testing.expectEqual(@as(i64, @intCast(a)), reconstructed);

        // Check a0 bounds (approximately)
        const bound: i32 = @intCast(alpha / 2);
        try testing.expect(@abs(a0) <= bound);
    }
}

test "polyDeriveUniform deterministic" {
    // Test that polyDeriveUniform produces deterministic results
    const seed: [32]u8 = .{0x01} ++ .{0x00} ** 31;
    const nonce: u16 = 0;

    const p1 = polyDeriveUniform(&seed, nonce);
    const p2 = polyDeriveUniform(&seed, nonce);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p1.cs[i], p2.cs[i]);
    }

    // All coefficients should be in [0, Q)
    for (0..N) |i| {
        try testing.expect(p1.cs[i] < Q);
    }
}

test "polyDeriveUniform different nonces" {
    // Test that different nonces produce different polynomials
    const seed: [32]u8 = .{0x01} ++ .{0x00} ** 31;

    const p1 = polyDeriveUniform(&seed, 0);
    const p2 = polyDeriveUniform(&seed, 1);

    // Should be different
    var different = false;
    for (0..N) |i| {
        if (p1.cs[i] != p2.cs[i]) {
            different = true;
            break;
        }
    }
    try testing.expect(different);
}

test "expandS with eta=2" {
    // Test eta=2 sampling
    const seed: [64]u8 = .{0x02} ++ .{0x00} ** 63;
    const nonce: u16 = 0;

    const p = expandS(2, &seed, nonce);

    // All coefficients should be in [Q-eta, Q+eta]
    // The function returns coefficients as Q + eta - t, where t is in [0, 2*eta]
    // So coefficients are in [Q-eta, Q+eta]
    for (0..N) |i| {
        const c = p.cs[i];
        // Check that c is in [Q-2, Q+2]
        try testing.expect(c >= Q - 2 and c <= Q + 2);
    }
}

test "expandS with eta=4" {
    // Test eta=4 sampling
    const seed: [64]u8 = .{0x03} ++ .{0x00} ** 63;
    const nonce: u16 = 0;

    const p = expandS(4, &seed, nonce);

    // All coefficients should be in [Q-eta, Q+eta]
    for (0..N) |i| {
        const c = p.cs[i];
        // Check bounds (coefficients are around Q ± eta)
        const diff = if (c >= Q) c - Q else Q - c;
        try testing.expect(diff <= 4);
    }
}

test "sampleInBall has correct weight" {
    // Test that ball polynomial has exactly tau non-zero coefficients
    const tau = 39; // From ML-DSA-44
    const seed: [32]u8 = .{0x04} ++ .{0x00} ** 31;

    const p = sampleInBall(tau, &seed);

    // Count non-zero coefficients
    var count: u32 = 0;
    for (0..N) |i| {
        if (p.cs[i] != 0) {
            count += 1;
            // Non-zero coefficients should be 1 or Q-1
            try testing.expect(p.cs[i] == 1 or p.cs[i] == Q - 1);
        }
    }

    try testing.expectEqual(tau, count);
}

test "sampleInBall deterministic" {
    // Test that ball sampling is deterministic
    const tau = 49; // From ML-DSA-65
    const seed: [32]u8 = .{0x05} ++ .{0x00} ** 31;

    const p1 = sampleInBall(tau, &seed);
    const p2 = sampleInBall(tau, &seed);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p1.cs[i], p2.cs[i]);
    }
}

test "polyPackLeqEta / polyUnpackLeqEta roundtrip for eta=2" {
    // Test packing and unpacking for eta=2
    const eta = 2;

    // Create a test polynomial with coefficients in [Q-eta, Q+eta]
    var p = Poly.zero;
    for (0..N) |i| {
        // Use various values in range
        const val = @as(u32, @intCast(i % 5)); // 0, 1, 2, 3, 4
        p.cs[i] = Q + eta - val;
    }

    // Pack it
    var buf: [96]u8 = undefined; // eta=2: 3 bits per coeff = 96 bytes
    polyPackLeqEta(p, eta, &buf);

    // Unpack it
    const p2 = polyUnpackLeqEta(eta, &buf);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p.cs[i], p2.cs[i]);
    }
}

test "polyPackLeqEta / polyUnpackLeqEta roundtrip for eta=4" {
    // Test packing and unpacking for eta=4
    const eta = 4;

    // Create a test polynomial with coefficients in [Q-eta, Q+eta]
    var p = Poly.zero;
    for (0..N) |i| {
        // Use various values in range
        const val = @as(u32, @intCast(i % 9)); // 0, 1, 2, ..., 8
        p.cs[i] = Q + eta - val;
    }

    // Pack it
    var buf: [128]u8 = undefined; // eta=4: 4 bits per coeff = 128 bytes
    polyPackLeqEta(p, eta, &buf);

    // Unpack it
    const p2 = polyUnpackLeqEta(eta, &buf);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p.cs[i], p2.cs[i]);
    }
}

test "polyPackT1 / polyUnpackT1 roundtrip" {
    // Create a test polynomial with coefficients < 1024
    var p = Poly.zero;
    for (0..N) |i| {
        p.cs[i] = @intCast(i % 1024);
    }

    // Pack it
    var buf: [320]u8 = undefined; // (256 * 10) / 8 = 320 bytes
    polyPackT1(p, &buf);

    // Unpack it
    const p2 = polyUnpackT1(&buf);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p.cs[i], p2.cs[i]);
    }
}

test "polyPackT0 / polyUnpackT0 roundtrip" {
    // Create a test polynomial with coefficients in (Q-2^12, Q+2^12]
    // This is the range (-2^12, 2^12] represented as unsigned around Q
    const bound = 1 << 12; // 2^(D-1) where D=13
    var p = Poly.zero;
    for (0..N) |i| {
        // Cycle through valid range for T0
        // Values should be Q + offset where offset is in (-bound, bound]
        const cycle_val = @as(i32, @intCast(i % (2 * bound))); // 0 to 2*bound-1
        const offset = cycle_val - bound + 1; // (-bound+1) to bound
        p.cs[i] = @as(u32, @intCast(@as(i32, Q) + offset));
    }

    // Pack it
    var buf: [416]u8 = undefined; // (256 * 13) / 8 = 416 bytes
    polyPackT0(p, &buf);

    // Unpack it
    const p2 = polyUnpackT0(&buf);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p.cs[i], p2.cs[i]);
    }
}

test "polyPackLeGamma1 / polyUnpackLeGamma1 roundtrip gamma1_bits=17" {
    const gamma1_bits = 17;
    const gamma1: u32 = @as(u32, 1) << gamma1_bits;

    // Create a test polynomial with coefficients in (-gamma1, gamma1]
    // Normalized: [0, gamma1] ∪ (Q-gamma1, Q)
    var p = Poly.zero;
    for (0..N) |i| {
        if (i % 2 == 0) {
            // Positive values: [0, gamma1]
            p.cs[i] = @intCast((i / 2) % (gamma1 + 1));
        } else {
            // Negative values: (Q-gamma1, Q)
            const neg_val: u32 = @intCast(((i / 2) % gamma1) + 1);
            p.cs[i] = Q - neg_val;
        }
    }

    // Pack it
    var buf: [576]u8 = undefined; // (256 * 18) / 8 = 576 bytes
    polyPackLeGamma1(p, gamma1_bits, &buf);

    // Unpack it
    const p2 = polyUnpackLeGamma1(gamma1_bits, &buf);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p.cs[i], p2.cs[i]);
    }
}

test "polyPackLeGamma1 / polyUnpackLeGamma1 roundtrip gamma1_bits=19" {
    const gamma1_bits = 19;
    const gamma1: u32 = @as(u32, 1) << gamma1_bits;

    // Create a test polynomial with coefficients in (-gamma1, gamma1]
    var p = Poly.zero;
    for (0..N) |i| {
        if (i % 2 == 0) {
            // Positive values: [0, gamma1]
            p.cs[i] = @intCast((i / 2) % (gamma1 + 1));
        } else {
            // Negative values: (Q-gamma1, Q)
            const neg_val: u32 = @intCast(((i / 2) % gamma1) + 1);
            p.cs[i] = Q - neg_val;
        }
    }

    // Pack it
    var buf: [640]u8 = undefined; // (256 * 20) / 8 = 640 bytes
    polyPackLeGamma1(p, gamma1_bits, &buf);

    // Unpack it
    const p2 = polyUnpackLeGamma1(gamma1_bits, &buf);

    // Should be identical
    for (0..N) |i| {
        try testing.expectEqual(p.cs[i], p2.cs[i]);
    }
}

test "polyPackW1 for gamma1_bits=17" {
    const gamma1_bits = 17;

    // Create a test polynomial with small coefficients (w1 values < 64)
    var p = Poly.zero;
    for (0..N) |i| {
        p.cs[i] = @intCast(i % 64); // 6-bit values
    }

    // Pack it
    var buf: [192]u8 = undefined; // (256 * 6) / 8 = 192 bytes
    polyPackW1(p, gamma1_bits, &buf);

    // Verify basic properties
    // All bytes should be used
    var non_zero = false;
    for (buf) |b| {
        if (b != 0) {
            non_zero = true;
            break;
        }
    }
    try testing.expect(non_zero);
}

test "polyPackW1 for gamma1_bits=19" {
    const gamma1_bits = 19;

    // Create a test polynomial with small coefficients (w1 values < 16)
    var p = Poly.zero;
    for (0..N) |i| {
        p.cs[i] = @intCast(i % 16); // 4-bit values
    }

    // Pack it
    var buf: [128]u8 = undefined; // (256 * 4) / 8 = 128 bytes
    polyPackW1(p, gamma1_bits, &buf);

    // Verify basic properties
    var non_zero = false;
    for (buf) |b| {
        if (b != 0) {
            non_zero = true;
            break;
        }
    }
    try testing.expect(non_zero);
}

test "makeHint and useHint correctness for gamma2=261888" {
    // Test for ML-DSA-65 and ML-DSA-87
    const gamma2: u32 = 261888;

    // Test a selection of values to verify the hint mechanism works
    const test_values = [_]u32{ 0, 100, 1000, 10000, 100000, 1000000, Q / 2, Q - 1 };

    for (test_values) |w| {
        // Decompose w to get w0 and w1
        const decomp = decompose(w, gamma2);
        const w0_plus_q = decomp.a0_plus_q;
        const w1 = decomp.a1;

        // Test with various small perturbations f in [0, gamma2]
        const perturbations = [_]u32{ 0, 1, 10, 100, 1000, gamma2 / 2, gamma2 };

        for (perturbations) |f| {
            // Test f (positive perturbation)
            const z0_pos = (w0_plus_q +% Q -% f) % Q;
            const hint_pos = makeHint(z0_pos, w1, gamma2);
            const w_perturbed_pos = (w +% Q -% f) % Q;
            const w1_recovered_pos = useHint(w_perturbed_pos, hint_pos, gamma2);
            try testing.expectEqual(w1, w1_recovered_pos);

            // Test -f (negative perturbation)
            if (f > 0) {
                const z0_neg = (w0_plus_q +% f) % Q;
                const hint_neg = makeHint(z0_neg, w1, gamma2);
                const w_perturbed_neg = (w +% f) % Q;
                const w1_recovered_neg = useHint(w_perturbed_neg, hint_neg, gamma2);
                try testing.expectEqual(w1, w1_recovered_neg);
            }
        }
    }
}

test "makeHint and useHint correctness for gamma2=95232" {
    // Test for ML-DSA-44
    const gamma2: u32 = 95232;

    // Test a selection of values to verify the hint mechanism works
    const test_values = [_]u32{ 0, 100, 1000, 10000, 100000, 1000000, Q / 2, Q - 1 };

    for (test_values) |w| {
        // Decompose w to get w0 and w1
        const decomp = decompose(w, gamma2);
        const w0_plus_q = decomp.a0_plus_q;
        const w1 = decomp.a1;

        // Test with various small perturbations f in [0, gamma2]
        const perturbations = [_]u32{ 0, 1, 10, 100, 1000, gamma2 / 2, gamma2 };

        for (perturbations) |f| {
            // Test f (positive perturbation)
            const z0_pos = (w0_plus_q +% Q -% f) % Q;
            const hint_pos = makeHint(z0_pos, w1, gamma2);
            const w_perturbed_pos = (w +% Q -% f) % Q;
            const w1_recovered_pos = useHint(w_perturbed_pos, hint_pos, gamma2);
            try testing.expectEqual(w1, w1_recovered_pos);

            // Test -f (negative perturbation)
            if (f > 0) {
                const z0_neg = (w0_plus_q +% f) % Q;
                const hint_neg = makeHint(z0_neg, w1, gamma2);
                const w_perturbed_neg = (w +% f) % Q;
                const w1_recovered_neg = useHint(w_perturbed_neg, hint_neg, gamma2);
                try testing.expectEqual(w1, w1_recovered_neg);
            }
        }
    }
}

test "polyMakeHint basic functionality" {
    const gamma2: u32 = 261888;

    // Create test polynomials
    var p0 = Poly.zero;
    var p1 = Poly.zero;

    // Fill with test values
    for (0..N) |i| {
        p0.cs[i] = @intCast((i * 17) % Q);
        p1.cs[i] = @intCast((i * 3) % 16); // High bits are at most 15 for gamma2=261888
    }

    // Make hints
    const result = polyMakeHint(p0, p1, gamma2);
    const hint = result.hint;
    const count = result.count;

    // Verify that hints are binary
    for (0..N) |i| {
        try testing.expect(hint.cs[i] == 0 or hint.cs[i] == 1);
    }

    // Verify that count matches the number of 1s in hint
    var actual_count: u32 = 0;
    for (0..N) |i| {
        actual_count += hint.cs[i];
    }
    try testing.expectEqual(count, actual_count);
}

test "polyUseHint reconstruction" {
    const gamma2: u32 = 261888;

    // Create a test polynomial q
    var q = Poly.zero;
    for (0..N) |i| {
        q.cs[i] = @intCast((i * 123) % Q);
    }

    // Decompose q to get high and low bits
    var q0_plus_q_array: [N]u32 = undefined;
    var q1_array: [N]u32 = undefined;
    for (0..N) |i| {
        const decomp = decompose(q.cs[i], gamma2);
        q0_plus_q_array[i] = decomp.a0_plus_q;
        q1_array[i] = decomp.a1;
    }

    const q0_plus_q = Poly{ .cs = q0_plus_q_array };
    const q1 = Poly{ .cs = q1_array };

    // Create hints (in this case, they'll mostly be 0 since q and q are the same)
    const hint_result = polyMakeHint(q0_plus_q, q1, gamma2);
    const hint = hint_result.hint;

    // Use hints to recover high bits
    const recovered = polyUseHint(q, hint, gamma2);

    // Recovered should match original high bits q1
    for (0..N) |i| {
        try testing.expectEqual(q1.cs[i], recovered.cs[i]);
    }
}

test "hint roundtrip with perturbation" {
    const gamma2: u32 = 261888;

    // Create a test polynomial w
    var w = Poly.zero;
    for (0..N) |i| {
        w.cs[i] = @intCast((i * 7919) % Q);
    }

    // Decompose w to get w0 and w1
    var w0_plus_q = Poly.zero;
    var w1 = Poly.zero;
    for (0..N) |i| {
        const decomp = decompose(w.cs[i], gamma2);
        w0_plus_q.cs[i] = decomp.a0_plus_q;
        w1.cs[i] = decomp.a1;
    }

    // Apply a small perturbation
    var f = Poly.zero;
    for (0..N) |i| {
        // Small perturbation in [-gamma2, gamma2]
        const f_val = @as(u32, @intCast(i % 1000));
        f.cs[i] = if (i % 2 == 0) f_val else Q -% f_val;
    }

    // Compute w' = w - f and z0 = w0 - f
    var w_prime = Poly.zero;
    var z0 = Poly.zero;
    for (0..N) |i| {
        w_prime.cs[i] = (w.cs[i] +% Q -% f.cs[i]) % Q;
        z0.cs[i] = (w0_plus_q.cs[i] +% Q -% f.cs[i]) % Q;
    }

    // Make hints
    const hint_result = polyMakeHint(z0, w1, gamma2);
    const hint = hint_result.hint;

    // Use hints to recover w1 from w_prime
    const w1_recovered = polyUseHint(w_prime, hint, gamma2);

    // Verify that we recovered the original high bits
    for (0..N) |i| {
        try testing.expectEqual(w1.cs[i], w1_recovered.cs[i]);
    }
}

// Parameterized test helper for key generation

fn testKeyGenerationBasic(comptime MlDsa: type, seed: [32]u8) !void {
    const result = MlDsa.newKeyFromSeed(&seed);
    const pk = result.pk;
    const sk = result.sk;

    // Basic sanity checks
    try testing.expect(pk.rho.len == 32);
    try testing.expect(sk.rho.len == 32);
    try testing.expectEqualSlices(u8, &pk.rho, &sk.rho);

    // Verify tr matches between pk and sk
    try testing.expectEqualSlices(u8, &pk.tr, &sk.tr);

    // Test toBytes/fromBytes round-trip for public key
    const pk_bytes = pk.toBytes();
    const pk2 = try MlDsa.PublicKey.fromBytes(pk_bytes);
    try testing.expectEqualSlices(u8, &pk.rho, &pk2.rho);
    try testing.expectEqualSlices(u8, &pk.tr, &pk2.tr);

    // Test toBytes/fromBytes round-trip for secret key
    const sk_bytes = sk.toBytes();
    const sk2 = try MlDsa.SecretKey.fromBytes(sk_bytes);
    try testing.expectEqualSlices(u8, &sk.rho, &sk2.rho);
    try testing.expectEqualSlices(u8, &sk.key, &sk2.key);
    try testing.expectEqualSlices(u8, &sk.tr, &sk2.tr);
}

test "Key generation basic - all variants" {
    inline for (.{
        .{ .variant = MLDSA44, .seed_byte = 0x44 },
        .{ .variant = MLDSA65, .seed_byte = 0x65 },
        .{ .variant = MLDSA87, .seed_byte = 0x87 },
    }) |config| {
        const seed = [_]u8{config.seed_byte} ** 32;
        try testKeyGenerationBasic(config.variant, seed);
    }
}

test "Key generation determinism" {
    const seed = [_]u8{ 0x12, 0x34, 0x56, 0x78 } ++ [_]u8{0xAB} ** 28;

    // Generate two key pairs from the same seed
    const result1 = MLDSA44.newKeyFromSeed(&seed);
    const result2 = MLDSA44.newKeyFromSeed(&seed);

    // They should be identical
    const pk_bytes1 = result1.pk.toBytes();
    const pk_bytes2 = result2.pk.toBytes();
    try testing.expectEqualSlices(u8, &pk_bytes1, &pk_bytes2);

    const sk_bytes1 = result1.sk.toBytes();
    const sk_bytes2 = result2.sk.toBytes();
    try testing.expectEqualSlices(u8, &sk_bytes1, &sk_bytes2);
}

test "Private key can compute public key" {
    const seed = [_]u8{0xFF} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const pk = result.pk;
    const sk = result.sk;

    // Compute public key from private key
    const pk_from_sk = sk.public();

    // Pack both public keys and compare
    const pk_bytes1 = pk.toBytes();
    const pk_bytes2 = pk_from_sk.toBytes();

    try testing.expectEqualSlices(u8, &pk_bytes1, &pk_bytes2);
}

// Parameterized test helper for sign and verify
fn testSignAndVerify(comptime MlDsa: type, seed: [32]u8, message: []const u8) !void {
    const result = MlDsa.newKeyFromSeed(&seed);
    const kp = try MlDsa.KeyPair.fromSecretKey(result.sk);

    // Sign the message
    const sig = try kp.sign(message, null);

    // Verify the signature
    try sig.verify(message, kp.public_key);
}

test "Sign and verify - all variants" {
    inline for (.{
        .{ .variant = MLDSA44, .seed_byte = 0x44, .message = "Hello, ML-DSA-44!" },
        .{ .variant = MLDSA65, .seed_byte = 0x65, .message = "Hello, ML-DSA-65!" },
        .{ .variant = MLDSA87, .seed_byte = 0x87, .message = "Hello, ML-DSA-87!" },
    }) |config| {
        const seed = [_]u8{config.seed_byte} ** 32;
        try testSignAndVerify(config.variant, seed, config.message);
    }
}

test "Invalid signature rejection" {
    const seed = [_]u8{0x99} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const kp = try MLDSA44.KeyPair.fromSecretKey(result.sk);

    const message = "Original message";

    // Sign the message
    const sig = try kp.sign(message, null);

    // Verify with wrong message should fail
    const wrong_message = "Modified message";
    try testing.expectError(error.SignatureVerificationFailed, sig.verify(wrong_message, kp.public_key));

    // Modify signature and verify should fail
    var corrupted_sig_bytes = sig.toBytes();
    corrupted_sig_bytes[0] ^= 0xFF;
    const corrupted_sig = try MLDSA44.Signature.fromBytes(corrupted_sig_bytes);
    try testing.expectError(error.SignatureVerificationFailed, corrupted_sig.verify(message, kp.public_key));
}

test "Context string support" {
    const seed = [_]u8{0xAA} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const kp = try MLDSA44.KeyPair.fromSecretKey(result.sk);

    const message = "Test message";
    const context1 = "context1";
    const context2 = "context2";

    // Sign with context1
    const sig1 = try kp.signWithContext(message, null, context1);

    // Verify with correct context should succeed
    try sig1.verifyWithContext(message, kp.public_key, context1);

    // Verify with wrong context should fail
    try testing.expectError(error.SignatureVerificationFailed, sig1.verifyWithContext(message, kp.public_key, context2));

    // Verify with empty context should fail
    try testing.expectError(error.SignatureVerificationFailed, sig1.verify(message, kp.public_key));

    // Sign with empty context
    const sig2 = try kp.sign(message, null);

    // Verify with empty context should succeed
    try sig2.verify(message, kp.public_key);

    // Verify with non-empty context should fail
    try testing.expectError(error.SignatureVerificationFailed, sig2.verifyWithContext(message, kp.public_key, context1));

    // Test maximum context length (255 bytes)
    const max_context = [_]u8{0xBB} ** 255;
    const sig3 = try kp.signWithContext(message, null, &max_context);
    try sig3.verifyWithContext(message, kp.public_key, &max_context);

    // Test context too long (256 bytes should fail)
    const too_long_context = [_]u8{0xCC} ** 256;
    try testing.expectError(error.ContextTooLong, kp.signWithContext(message, null, &too_long_context));
}

test "Context string with streaming API" {
    const seed = [_]u8{0xDD} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const kp = try MLDSA44.KeyPair.fromSecretKey(result.sk);

    const context = "streaming-context";
    const message_part1 = "Hello, ";
    const message_part2 = "World!";

    // Sign using streaming API with context
    var signer = try kp.signerWithContext(null, context);
    signer.update(message_part1);
    signer.update(message_part2);
    const sig = signer.finalize();

    // Verify using streaming API with context
    var verifier = try sig.verifierWithContext(kp.public_key, context);
    verifier.update(message_part1);
    verifier.update(message_part2);
    try verifier.verify();

    // Verify with wrong context should fail
    var verifier_wrong = try sig.verifierWithContext(kp.public_key, "wrong");
    verifier_wrong.update(message_part1);
    verifier_wrong.update(message_part2);
    try testing.expectError(error.SignatureVerificationFailed, verifier_wrong.verify());
}

test "Signature determinism (same rnd)" {
    const seed = [_]u8{0x11} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const sk = result.sk;

    const message = "Deterministic test";
    const rnd = [_]u8{0x22} ** 32;

    // Sign twice with same randomness using streaming API
    var st1 = try sk.signer(rnd);
    st1.update(message);
    const sig1 = st1.finalize();

    var st2 = try sk.signer(rnd);
    st2.update(message);
    const sig2 = st2.finalize();

    // Signatures should be identical
    try testing.expectEqualSlices(u8, &sig1.toBytes(), &sig2.toBytes());
}

test "Signature toBytes/fromBytes roundtrip" {
    const seed = [_]u8{0x33} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const kp = try MLDSA44.KeyPair.fromSecretKey(result.sk);

    const message = "toBytes/fromBytes test";

    // Sign the message
    const sig = try kp.sign(message, null);
    const sig_bytes = sig.toBytes();

    // Unpack and repack
    const sig_reparsed = try MLDSA44.Signature.fromBytes(sig_bytes);

    const repacked = sig_reparsed.toBytes();

    // Should match original
    try testing.expectEqualSlices(u8, &sig_bytes, &repacked);
}

test "Empty message signing" {
    const seed = [_]u8{0x44} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const kp = try MLDSA44.KeyPair.fromSecretKey(result.sk);

    const message = "";

    // Sign empty message
    const sig = try kp.sign(message, null);

    // Verify should work
    try sig.verify(message, kp.public_key);
}

test "Long message signing" {
    const seed = [_]u8{0x55} ** 32;
    const result = MLDSA44.newKeyFromSeed(&seed);
    const kp = try MLDSA44.KeyPair.fromSecretKey(result.sk);

    // Create a long message (1KB)
    const long_message = [_]u8{0xAB} ** 1024;

    // Sign long message
    const sig = try kp.sign(&long_message, null);

    // Verify should work
    try sig.verify(&long_message, kp.public_key);
}

// Helper function to decode hex string into bytes
fn hexToBytes(comptime hex: []const u8, out: []u8) !void {
    if (hex.len != out.len * 2) return error.InvalidLength;

    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        const hi = try std.fmt.charToDigit(hex[i * 2], 16);
        const lo = try std.fmt.charToDigit(hex[i * 2 + 1], 16);
        out[i] = (hi << 4) | lo;
    }
}

test "ML-DSA-44 KAT test vector 0" {
    // Test vector from NIST ML-DSA KAT (count = 0)
    // xi is the seed for key generation (Algorithm 1, line 1)
    const xi_hex = "f696484048ec21f96cf50a56d0759c448f3779752f0383d37449690694cf7a68";
    const pk_hex_start = "bd4e96f9a038ab5e36214fe69c0b1cb835ef9d7c8417e76aecd152f5cddebec8";
    const msg_hex = "6dbbc4375136df3b07f7c70e639e223e";

    // Parse xi (32-byte seed for key generation)
    var xi: [32]u8 = undefined;
    try hexToBytes(xi_hex, &xi);

    // Generate keys from xi
    const result = MLDSA44.newKeyFromSeed(&xi);
    const pk = result.pk;
    const sk = result.sk;

    // Verify public key starts with expected bytes
    const pk_bytes = pk.toBytes();

    var expected_pk_start: [32]u8 = undefined;
    try hexToBytes(pk_hex_start, &expected_pk_start);

    // Check first 32 bytes of public key match
    try testing.expectEqualSlices(u8, &expected_pk_start, pk_bytes[0..32]);

    // Parse message
    var msg: [16]u8 = undefined;
    try hexToBytes(msg_hex, &msg);

    // Sign the message (deterministic mode with fixed randomness)
    const kp = try MLDSA44.KeyPair.fromSecretKey(sk);
    const sig = try kp.sign(&msg, null);

    // Verify the signature
    try sig.verify(&msg, kp.public_key);
}

test "ML-DSA-65 KAT test vector 0" {
    // Test vector from NIST ML-DSA KAT (count = 0)
    // xi is the seed for key generation (Algorithm 1, line 1)
    const xi_hex = "f696484048ec21f96cf50a56d0759c448f3779752f0383d37449690694cf7a68";
    const pk_hex_start = "e50d03fff3b3a70961abbb92a390008dec1283f603f50cdbaaa3d00bd659bc76";
    const msg_hex = "6dbbc4375136df3b07f7c70e639e223e";

    // Parse xi (32-byte seed for key generation)
    var xi: [32]u8 = undefined;
    try hexToBytes(xi_hex, &xi);

    // Generate keys from xi
    const result = MLDSA65.newKeyFromSeed(&xi);
    const pk = result.pk;
    const sk = result.sk;

    // Verify public key starts with expected bytes
    const pk_bytes = pk.toBytes();

    var expected_pk_start: [32]u8 = undefined;
    try hexToBytes(pk_hex_start, &expected_pk_start);

    // Check first 32 bytes of public key match
    try testing.expectEqualSlices(u8, &expected_pk_start, pk_bytes[0..32]);

    // Parse message
    var msg: [16]u8 = undefined;
    try hexToBytes(msg_hex, &msg);

    // Sign the message
    const kp = try MLDSA65.KeyPair.fromSecretKey(sk);
    const sig = try kp.sign(&msg, null);

    // Verify the signature
    try sig.verify(&msg, kp.public_key);
}

test "ML-DSA-87 KAT test vector 0" {
    // Test vector from NIST ML-DSA KAT (count = 0)
    // xi is the seed for key generation (Algorithm 1, line 1)
    const xi_hex = "f696484048ec21f96cf50a56d0759c448f3779752f0383d37449690694cf7a68";
    const pk_hex_start = "bc89b367d4288f47c71a74679d0fcffbe041de41b5da2f5fc66d8e28c5899494";
    const msg_hex = "6dbbc4375136df3b07f7c70e639e223e";

    // Parse xi (32-byte seed for key generation)
    var xi: [32]u8 = undefined;
    try hexToBytes(xi_hex, &xi);

    // Generate keys from xi
    const result = MLDSA87.newKeyFromSeed(&xi);
    const pk = result.pk;
    const sk = result.sk;

    // Verify public key starts with expected bytes
    const pk_bytes = pk.toBytes();

    var expected_pk_start: [32]u8 = undefined;
    try hexToBytes(pk_hex_start, &expected_pk_start);

    // Check first 32 bytes of public key match
    try testing.expectEqualSlices(u8, &expected_pk_start, pk_bytes[0..32]);

    // Parse message
    var msg: [16]u8 = undefined;
    try hexToBytes(msg_hex, &msg);

    // Sign the message
    const kp = try MLDSA87.KeyPair.fromSecretKey(sk);
    const sig = try kp.sign(&msg, null);

    // Verify the signature
    try sig.verify(&msg, kp.public_key);
}

test "KeyPair API - generate and sign" {
    // Test the new KeyPair API with random generation
    const kp = MLDSA44.KeyPair.generate();
    const msg = "Test message for KeyPair API";

    // Sign with deterministic mode (no noise)
    const sig = try kp.sign(msg, null);

    // Verify using Signature.verify API
    try sig.verify(msg, kp.public_key);
}

test "KeyPair API - generateDeterministic" {
    // Test deterministic key generation
    const seed = [_]u8{42} ** 32;
    const kp1 = try MLDSA44.KeyPair.generateDeterministic(seed);
    const kp2 = try MLDSA44.KeyPair.generateDeterministic(seed);

    // Same seed should produce same keys
    const pk1_bytes = kp1.public_key.toBytes();
    const pk2_bytes = kp2.public_key.toBytes();
    try testing.expectEqualSlices(u8, &pk1_bytes, &pk2_bytes);
}

test "KeyPair API - fromSecretKey" {
    // Generate a key pair
    const kp1 = MLDSA44.KeyPair.generate();

    // Derive public key from secret key
    const kp2 = try MLDSA44.KeyPair.fromSecretKey(kp1.secret_key);

    // Public keys should match
    const pk1_bytes = kp1.public_key.toBytes();
    const pk2_bytes = kp2.public_key.toBytes();
    try testing.expectEqualSlices(u8, &pk1_bytes, &pk2_bytes);
}

test "Signature verification with noise" {
    // Test signing with randomness (hedged signatures)
    const kp = MLDSA65.KeyPair.generate();
    const msg = "Message to be signed with randomness";

    // Create some noise
    const noise = [_]u8{ 1, 2, 3, 4, 5 } ++ [_]u8{0} ** 27;

    // Sign with noise
    const sig = try kp.sign(msg, noise);

    // Verify should still work
    try sig.verify(msg, kp.public_key);
}

test "Signature verification failure" {
    // Test that invalid signatures are rejected
    const kp = MLDSA44.KeyPair.generate();
    const msg = "Original message";
    const sig = try kp.sign(msg, null);

    // Verify with wrong message should fail
    const wrong_msg = "Different message";
    try testing.expectError(error.SignatureVerificationFailed, sig.verify(wrong_msg, kp.public_key));
}

test "Streaming API - sign and verify" {
    const seed = [_]u8{0x55} ** 32;
    const kp = try MLDSA44.KeyPair.generateDeterministic(seed);

    const msg = "Test message for streaming API";

    // Sign using streaming API
    var signer = try kp.signer(null);
    signer.update(msg);
    const sig = signer.finalize();

    // Verify using streaming API
    var verifier = try sig.verifier(kp.public_key);
    verifier.update(msg);
    try verifier.verify();
}

test "Streaming API - chunked message" {
    const seed = [_]u8{0x66} ** 32;
    const kp = try MLDSA44.KeyPair.generateDeterministic(seed);

    // Create a message in chunks
    const chunk1 = "Hello, ";
    const chunk2 = "streaming ";
    const chunk3 = "world!";
    const full_msg = chunk1 ++ chunk2 ++ chunk3;

    // Sign with chunks
    var signer = try kp.signer(null);
    signer.update(chunk1);
    signer.update(chunk2);
    signer.update(chunk3);
    const sig_chunked = signer.finalize();

    // Sign with full message for comparison
    var signer2 = try kp.signer(null);
    signer2.update(full_msg);
    const sig_full = signer2.finalize();

    // Signatures should be identical
    try testing.expectEqualSlices(u8, &sig_chunked.toBytes(), &sig_full.toBytes());

    // Verify with chunks
    const sig = sig_chunked;
    var verifier = try sig.verifier(kp.public_key);
    verifier.update(chunk1);
    verifier.update(chunk2);
    verifier.update(chunk3);
    try verifier.verify();
}

test "Streaming API - large message" {
    const seed = [_]u8{0x77} ** 32;
    const kp = try MLDSA44.KeyPair.generateDeterministic(seed);

    // Create a large message (1MB)
    const chunk_size = 4096;
    const num_chunks = 256;
    var chunk: [chunk_size]u8 = undefined;
    for (0..chunk_size) |i| {
        chunk[i] = @intCast(i % 256);
    }

    // Sign streaming
    var signer = try kp.signer(null);
    for (0..num_chunks) |_| {
        signer.update(&chunk);
    }
    const sig = signer.finalize();

    // Verify streaming
    var verifier = try sig.verifier(kp.public_key);
    for (0..num_chunks) |_| {
        verifier.update(&chunk);
    }
    try verifier.verify();
}

test "Streaming API - all parameter sets" {
    const test_msg = "Streaming test for all ML-DSA parameter sets";

    // ML-DSA-44
    {
        const seed = [_]u8{0x44} ** 32;
        const kp = try MLDSA44.KeyPair.generateDeterministic(seed);
        var signer = try kp.signer(null);
        signer.update(test_msg);
        const sig = signer.finalize();
        var verifier = try sig.verifier(kp.public_key);
        verifier.update(test_msg);
        try verifier.verify();
    }

    // ML-DSA-65
    {
        const seed = [_]u8{0x65} ** 32;
        const kp = try MLDSA65.KeyPair.generateDeterministic(seed);
        var signer = try kp.signer(null);
        signer.update(test_msg);
        const sig = signer.finalize();
        var verifier = try sig.verifier(kp.public_key);
        verifier.update(test_msg);
        try verifier.verify();
    }

    // ML-DSA-87
    {
        const seed = [_]u8{0x87} ** 32;
        const kp = try MLDSA87.KeyPair.generateDeterministic(seed);
        var signer = try kp.signer(null);
        signer.update(test_msg);
        const sig = signer.finalize();
        var verifier = try sig.verifier(kp.public_key);
        verifier.update(test_msg);
        try verifier.verify();
    }
}

/// Extended Euclidian Algorithm
/// Only meant to be used on comptime values; correctness matters, performance doesn't.
fn extendedEuclidean(comptime T: type, comptime a_: T, comptime b_: T) struct { gcd: T, x: T, y: T } {
    var a = a_;
    var b = b_;
    var x0: T = 1;
    var x1: T = 0;
    var y0: T = 0;
    var y1: T = 1;

    while (b != 0) {
        const q = @divTrunc(a, b);
        const temp_a = a;
        a = b;
        b = temp_a - q * b;

        const temp_x = x0;
        x0 = x1;
        x1 = temp_x - q * x1;

        const temp_y = y0;
        y0 = y1;
        y1 = temp_y - q * y1;
    }

    return .{ .gcd = a, .x = x0, .y = y0 };
}

/// Modular inversion: computes a^(-1) mod p
/// Requires gcd(a,p) = 1. The result is normalized to the range [0, p).
fn modularInverse(comptime T: type, comptime a: T, comptime p: T) T {
    // Use a signed type for EEA computation
    const type_info = @typeInfo(T);
    const SignedT = if (type_info == .int and type_info.int.signedness == .unsigned)
        std.meta.Int(.signed, type_info.int.bits)
    else
        T;

    const a_signed = @as(SignedT, @intCast(a));
    const p_signed = @as(SignedT, @intCast(p));

    const r = extendedEuclidean(SignedT, a_signed, p_signed);
    assert(r.gcd == 1);

    // Normalize result to [0, p)
    var result = r.x;
    while (result < 0) {
        result += p_signed;
    }

    return @intCast(result);
}

/// Modular exponentiation: computes a^s mod p using square-and-multiply algorithm.
fn modularPow(comptime T: type, comptime a: T, s: T, comptime p: T) T {
    const type_info = @typeInfo(T);
    const bits = type_info.int.bits;
    const WideT = std.meta.Int(.unsigned, bits * 2);

    var ret: T = 1;
    var base: T = a;
    var exp = s;

    while (exp > 0) {
        if (exp & 1 == 1) {
            ret = @intCast((@as(WideT, ret) * @as(WideT, base)) % p);
        }
        base = @intCast((@as(WideT, base) * @as(WideT, base)) % p);
        exp >>= 1;
    }

    return ret;
}

/// Creates an all-ones or all-zeros mask from a single bit value.
/// Returns all 1s (0xFF...FF) if bit == 1, all 0s if bit == 0.
fn bitMask(comptime T: type, bit: T) T {
    const type_info = @typeInfo(T);
    if (type_info != .int or type_info.int.signedness != .unsigned) {
        @compileError("bitMask requires an unsigned integer type");
    }
    return -%bit;
}

/// Creates a mask from the sign bit of a signed integer.
/// Returns all 1s (0xFF...FF) if x < 0, all 0s if x >= 0.
fn signMask(comptime T: type, x: T) std.meta.Int(.unsigned, @typeInfo(T).int.bits) {
    const type_info = @typeInfo(T);
    if (type_info != .int) {
        @compileError("signMask requires an integer type");
    }

    const bits = type_info.int.bits;
    const SignedT = std.meta.Int(.signed, bits);

    // Convert to signed if needed, arithmetic right shift to propagate sign bit
    const x_signed: SignedT = if (type_info.int.signedness == .signed) x else @bitCast(x);
    const shifted = x_signed >> (bits - 1);
    return @bitCast(shifted);
}

/// Montgomery reduction: for input x, returns y where y ≡ x*R^(-1) (mod q).
/// This is a generic implementation parameterized by the modulus q, its inverse qInv,
/// the Montgomery constant R, and the result bound.
///
/// For ML-DSA: R = 2^32, returns y < 2q
/// For ML-KEM: R = 2^16, returns y in range (-q, q)
fn montgomeryReduce(
    comptime InT: type,
    comptime OutT: type,
    comptime q: comptime_int,
    comptime qInv: comptime_int,
    comptime r_bits: comptime_int,
    x: InT,
) OutT {
    const mask = (@as(InT, 1) << r_bits) - 1;
    const m_full = (x *% qInv) & mask;
    const m: OutT = @truncate(m_full);

    const yR = x -% @as(InT, m) * @as(InT, q);
    const y_shifted = @as(std.meta.Int(.unsigned, @typeInfo(InT).Int.bits), @bitCast(yR)) >> r_bits;
    return @bitCast(@as(std.meta.Int(.unsigned, @typeInfo(OutT).Int.bits), @truncate(y_shifted)));
}

/// Uniform sampling using SHAKE-128 with rejection sampling.
/// Samples polynomial coefficients uniformly from [0, q) using rejection sampling.
///
/// Parameters:
/// - PolyType: The polynomial type to return
/// - q: Modulus
/// - bits_per_coef: Number of bits per coefficient (12 or 23)
/// - n: Number of coefficients
/// - seed: Random seed
/// - domain_sep: Domain separation bytes (appended to seed)
fn sampleUniformRejection(
    comptime PolyType: type,
    comptime q: comptime_int,
    comptime bits_per_coef: comptime_int,
    comptime n: comptime_int,
    seed: []const u8,
    domain_sep: []const u8,
) PolyType {
    var h = sha3.Shake128.init(.{});
    h.update(seed);
    h.update(domain_sep);

    const buf_len = sha3.Shake128.block_length; // 168 bytes
    var buf: [buf_len]u8 = undefined;

    var ret: PolyType = undefined;
    var coef_idx: usize = 0;

    if (bits_per_coef == 12) {
        // ML-KEM path: pack 2 coefficients per 3 bytes (12 bits each)
        outer: while (true) {
            h.squeeze(&buf);

            var j: usize = 0;
            while (j < buf_len) : (j += 3) {
                const b0 = @as(u16, buf[j]);
                const b1 = @as(u16, buf[j + 1]);
                const b2 = @as(u16, buf[j + 2]);

                const ts: [2]u16 = .{
                    b0 | ((b1 & 0xf) << 8),
                    (b1 >> 4) | (b2 << 4),
                };

                inline for (ts) |t| {
                    if (t < q) {
                        ret.cs[coef_idx] = @intCast(t);
                        coef_idx += 1;
                        if (coef_idx == n) break :outer;
                    }
                }
            }
        }
    } else if (bits_per_coef == 23) {
        // ML-DSA path: 1 coefficient per 3 bytes (23 bits)
        while (coef_idx < n) {
            h.squeeze(&buf);

            var j: usize = 0;
            while (j < buf_len and coef_idx < n) : (j += 3) {
                const t = (@as(u32, buf[j]) |
                    (@as(u32, buf[j + 1]) << 8) |
                    (@as(u32, buf[j + 2]) << 16)) & 0x7fffff;

                if (t < q) {
                    ret.cs[coef_idx] = @intCast(t);
                    coef_idx += 1;
                }
            }
        }
    } else {
        @compileError("bits_per_coef must be 12 or 23");
    }

    return ret;
}

test "bitMask and signMask helpers" {
    try testing.expectEqual(@as(u32, 0x00000000), bitMask(u32, 0));
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), bitMask(u32, 1));
    try testing.expectEqual(@as(u8, 0x00), bitMask(u8, 0));
    try testing.expectEqual(@as(u8, 0xFF), bitMask(u8, 1));
    try testing.expectEqual(@as(u64, 0x0000000000000000), bitMask(u64, 0));
    try testing.expectEqual(@as(u64, 0xFFFFFFFFFFFFFFFF), bitMask(u64, 1));

    try testing.expectEqual(@as(u32, 0xFFFFFFFF), signMask(i32, -1));
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), signMask(i32, -100));
    try testing.expectEqual(@as(u32, 0x00000000), signMask(i32, 0));
    try testing.expectEqual(@as(u32, 0x00000000), signMask(i32, 1));
    try testing.expectEqual(@as(u32, 0x00000000), signMask(i32, 100));

    try testing.expectEqual(@as(u32, 0xFFFFFFFF), signMask(u32, 0x80000000)); // MSB set
    try testing.expectEqual(@as(u32, 0x00000000), signMask(u32, 0x7FFFFFFF)); // MSB clear
}

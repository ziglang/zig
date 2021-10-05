// Ported from musl, which is MIT licensed:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/fmal.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/fmaf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/fma.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns x * y + z with a single rounding error.
pub fn fma(comptime T: type, x: T, y: T, z: T) T {
    return switch (T) {
        f32 => fma32(x, y, z),
        f64 => fma64(x, y, z),
        f128 => fma128(x, y, z),

        // TODO this is not correct for some targets
        c_longdouble => @floatCast(c_longdouble, fma128(x, y, z)),

        else => @compileError("fma not implemented for " ++ @typeName(T)),
    };
}

fn fma32(x: f32, y: f32, z: f32) f32 {
    const xy = @as(f64, x) * y;
    const xy_z = xy + z;
    const u = @bitCast(u64, xy_z);
    const e = (u >> 52) & 0x7FF;

    if ((u & 0x1FFFFFFF) != 0x10000000 or e == 0x7FF or (xy_z - xy == z and xy_z - z == xy)) {
        return @floatCast(f32, xy_z);
    } else {
        // TODO: Handle inexact case with double-rounding
        return @floatCast(f32, xy_z);
    }
}

// NOTE: Upstream fma.c has been rewritten completely to raise fp exceptions more accurately.
fn fma64(x: f64, y: f64, z: f64) f64 {
    if (!math.isFinite(x) or !math.isFinite(y)) {
        return x * y + z;
    }
    if (!math.isFinite(z)) {
        return z;
    }
    if (x == 0.0 or y == 0.0) {
        return x * y + z;
    }
    if (z == 0.0) {
        return x * y;
    }

    const x1 = math.frexp(x);
    var ex = x1.exponent;
    var xs = x1.significand;
    const x2 = math.frexp(y);
    var ey = x2.exponent;
    var ys = x2.significand;
    const x3 = math.frexp(z);
    var ez = x3.exponent;
    var zs = x3.significand;

    var spread = ex + ey - ez;
    if (spread <= 53 * 2) {
        zs = math.scalbn(zs, -spread);
    } else {
        zs = math.copysign(f64, math.f64_min, zs);
    }

    const xy = dd_mul(xs, ys);
    const r = dd_add(xy.hi, zs);
    spread = ex + ey;

    if (r.hi == 0.0) {
        return xy.hi + zs + math.scalbn(xy.lo, spread);
    }

    const adj = add_adjusted(r.lo, xy.lo);
    if (spread + math.ilogb(r.hi) > -1023) {
        return math.scalbn(r.hi + adj, spread);
    } else {
        return add_and_denorm(r.hi, adj, spread);
    }
}

const dd = struct {
    hi: f64,
    lo: f64,
};

fn dd_add(a: f64, b: f64) dd {
    var ret: dd = undefined;
    ret.hi = a + b;
    const s = ret.hi - a;
    ret.lo = (a - (ret.hi - s)) + (b - s);
    return ret;
}

fn dd_mul(a: f64, b: f64) dd {
    var ret: dd = undefined;
    const split: f64 = 0x1.0p27 + 1.0;

    var p = a * split;
    var ha = a - p;
    ha += p;
    var la = a - ha;

    p = b * split;
    var hb = b - p;
    hb += p;
    var lb = b - hb;

    p = ha * hb;
    var q = ha * lb + la * hb;

    ret.hi = p + q;
    ret.lo = p - ret.hi + q + la * lb;
    return ret;
}

fn add_adjusted(a: f64, b: f64) f64 {
    var sum = dd_add(a, b);
    if (sum.lo != 0) {
        var uhii = @bitCast(u64, sum.hi);
        if (uhii & 1 == 0) {
            // hibits += copysign(1.0, sum.hi, sum.lo)
            const uloi = @bitCast(u64, sum.lo);
            uhii += 1 - ((uhii ^ uloi) >> 62);
            sum.hi = @bitCast(f64, uhii);
        }
    }
    return sum.hi;
}

fn add_and_denorm(a: f64, b: f64, scale: i32) f64 {
    var sum = dd_add(a, b);
    if (sum.lo != 0) {
        var uhii = @bitCast(u64, sum.hi);
        const bits_lost = -@intCast(i32, (uhii >> 52) & 0x7FF) - scale + 1;
        if ((bits_lost != 1) == (uhii & 1 != 0)) {
            const uloi = @bitCast(u64, sum.lo);
            uhii += 1 - (((uhii ^ uloi) >> 62) & 2);
            sum.hi = @bitCast(f64, uhii);
        }
    }
    return math.scalbn(sum.hi, scale);
}

/// A struct that represents a floating-point number with twice the precision
/// of f128.  We maintain the invariant that "hi" stores the high-order
/// bits of the result.
const dd128 = struct {
    hi: f128,
    lo: f128,
};

/// Compute a+b exactly, returning the exact result in a struct dd.  We assume
/// that both a and b are finite, but make no assumptions about their relative
/// magnitudes.
fn dd_add128(a: f128, b: f128) dd128 {
    var ret: dd128 = undefined;
    ret.hi = a + b;
    const s = ret.hi - a;
    ret.lo = (a - (ret.hi - s)) + (b - s);
    return ret;
}

/// Compute a+b, with a small tweak:  The least significant bit of the
/// result is adjusted into a sticky bit summarizing all the bits that
/// were lost to rounding.  This adjustment negates the effects of double
/// rounding when the result is added to another number with a higher
/// exponent.  For an explanation of round and sticky bits, see any reference
/// on FPU design, e.g.,
///
///     J. Coonen.  An Implementation Guide to a Proposed Standard for
///     Floating-Point Arithmetic.  Computer, vol. 13, no. 1, Jan 1980.
fn add_adjusted128(a: f128, b: f128) f128 {
    var sum = dd_add128(a, b);
    if (sum.lo != 0) {
        var uhii = @bitCast(u128, sum.hi);
        if (uhii & 1 == 0) {
            // hibits += copysign(1.0, sum.hi, sum.lo)
            const uloi = @bitCast(u128, sum.lo);
            uhii += 1 - ((uhii ^ uloi) >> 126);
            sum.hi = @bitCast(f128, uhii);
        }
    }
    return sum.hi;
}

/// Compute ldexp(a+b, scale) with a single rounding error. It is assumed
/// that the result will be subnormal, and care is taken to ensure that
/// double rounding does not occur.
fn add_and_denorm128(a: f128, b: f128, scale: i32) f128 {
    var sum = dd_add128(a, b);
    // If we are losing at least two bits of accuracy to denormalization,
    // then the first lost bit becomes a round bit, and we adjust the
    // lowest bit of sum.hi to make it a sticky bit summarizing all the
    // bits in sum.lo. With the sticky bit adjusted, the hardware will
    // break any ties in the correct direction.
    //
    // If we are losing only one bit to denormalization, however, we must
    // break the ties manually.
    if (sum.lo != 0) {
        var uhii = @bitCast(u128, sum.hi);
        const bits_lost = -@intCast(i32, (uhii >> 112) & 0x7FFF) - scale + 1;
        if ((bits_lost != 1) == (uhii & 1 != 0)) {
            const uloi = @bitCast(u128, sum.lo);
            uhii += 1 - (((uhii ^ uloi) >> 126) & 2);
            sum.hi = @bitCast(f128, uhii);
        }
    }
    return math.scalbn(sum.hi, scale);
}

/// Compute a*b exactly, returning the exact result in a struct dd.  We assume
/// that both a and b are normalized, so no underflow or overflow will occur.
/// The current rounding mode must be round-to-nearest.
fn dd_mul128(a: f128, b: f128) dd128 {
    var ret: dd128 = undefined;
    const split: f128 = 0x1.0p57 + 1.0;

    var p = a * split;
    var ha = a - p;
    ha += p;
    var la = a - ha;

    p = b * split;
    var hb = b - p;
    hb += p;
    var lb = b - hb;

    p = ha * hb;
    var q = ha * lb + la * hb;

    ret.hi = p + q;
    ret.lo = p - ret.hi + q + la * lb;
    return ret;
}

/// Fused multiply-add: Compute x * y + z with a single rounding error.
///
/// We use scaling to avoid overflow/underflow, along with the
/// canonical precision-doubling technique adapted from:
///
///      Dekker, T.  A Floating-Point Technique for Extending the
///      Available Precision.  Numer. Math. 18, 224-242 (1971).
fn fma128(x: f128, y: f128, z: f128) f128 {
    if (!math.isFinite(x) or !math.isFinite(y)) {
        return x * y + z;
    }
    if (!math.isFinite(z)) {
        return z;
    }
    if (x == 0.0 or y == 0.0) {
        return x * y + z;
    }
    if (z == 0.0) {
        return x * y;
    }

    const x1 = math.frexp(x);
    var ex = x1.exponent;
    var xs = x1.significand;
    const x2 = math.frexp(y);
    var ey = x2.exponent;
    var ys = x2.significand;
    const x3 = math.frexp(z);
    var ez = x3.exponent;
    var zs = x3.significand;

    var spread = ex + ey - ez;
    if (spread <= 113 * 2) {
        zs = math.scalbn(zs, -spread);
    } else {
        zs = math.copysign(f128, math.f128_min, zs);
    }

    const xy = dd_mul128(xs, ys);
    const r = dd_add128(xy.hi, zs);
    spread = ex + ey;

    if (r.hi == 0.0) {
        return xy.hi + zs + math.scalbn(xy.lo, spread);
    }

    const adj = add_adjusted128(r.lo, xy.lo);
    if (spread + math.ilogb(r.hi) > -16383) {
        return math.scalbn(r.hi + adj, spread);
    } else {
        return add_and_denorm128(r.hi, adj, spread);
    }
}

test "type dispatch" {
    try expect(fma(f32, 0.0, 1.0, 1.0) == fma32(0.0, 1.0, 1.0));
    try expect(fma(f64, 0.0, 1.0, 1.0) == fma64(0.0, 1.0, 1.0));
    try expect(fma(f128, 0.0, 1.0, 1.0) == fma128(0.0, 1.0, 1.0));
}

test "32" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f32, fma32(0.0, 5.0, 9.124), 9.124, epsilon));
    try expect(math.approxEqAbs(f32, fma32(0.2, 5.0, 9.124), 10.124, epsilon));
    try expect(math.approxEqAbs(f32, fma32(0.8923, 5.0, 9.124), 13.5855, epsilon));
    try expect(math.approxEqAbs(f32, fma32(1.5, 5.0, 9.124), 16.624, epsilon));
    try expect(math.approxEqAbs(f32, fma32(37.45, 5.0, 9.124), 196.374004, epsilon));
    try expect(math.approxEqAbs(f32, fma32(89.123, 5.0, 9.124), 454.739005, epsilon));
    try expect(math.approxEqAbs(f32, fma32(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

test "64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, fma64(0.0, 5.0, 9.124), 9.124, epsilon));
    try expect(math.approxEqAbs(f64, fma64(0.2, 5.0, 9.124), 10.124, epsilon));
    try expect(math.approxEqAbs(f64, fma64(0.8923, 5.0, 9.124), 13.5855, epsilon));
    try expect(math.approxEqAbs(f64, fma64(1.5, 5.0, 9.124), 16.624, epsilon));
    try expect(math.approxEqAbs(f64, fma64(37.45, 5.0, 9.124), 196.374, epsilon));
    try expect(math.approxEqAbs(f64, fma64(89.123, 5.0, 9.124), 454.739, epsilon));
    try expect(math.approxEqAbs(f64, fma64(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

test "128" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f128, fma128(0.0, 5.0, 9.124), 9.124, epsilon));
    try expect(math.approxEqAbs(f128, fma128(0.2, 5.0, 9.124), 10.124, epsilon));
    try expect(math.approxEqAbs(f128, fma128(0.8923, 5.0, 9.124), 13.5855, epsilon));
    try expect(math.approxEqAbs(f128, fma128(1.5, 5.0, 9.124), 16.624, epsilon));
    try expect(math.approxEqAbs(f128, fma128(37.45, 5.0, 9.124), 196.374, epsilon));
    try expect(math.approxEqAbs(f128, fma128(89.123, 5.0, 9.124), 454.739, epsilon));
    try expect(math.approxEqAbs(f128, fma128(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

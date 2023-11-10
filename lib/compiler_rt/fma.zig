//! Ported from musl, which is MIT licensed:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/fmal.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/fmaf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/fma.c

const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__fmah, .{ .name = "__fmah", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmaf, .{ .name = "fmaf", .linkage = common.linkage, .visibility = common.visibility });
    @export(fma, .{ .name = "fma", .linkage = common.linkage, .visibility = common.visibility });
    @export(__fmax, .{ .name = "__fmax", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(fmaq, .{ .name = "fmaf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(fmaq, .{ .name = "fmaq", .linkage = common.linkage, .visibility = common.visibility });
    @export(fmal, .{ .name = "fmal", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __fmah(x: f16, y: f16, z: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(fmaf(x, y, z));
}

pub fn fmaf(x: f32, y: f32, z: f32) callconv(.C) f32 {
    const xy = @as(f64, x) * y;
    const xy_z = xy + z;
    const u = @as(u64, @bitCast(xy_z));
    const e = (u >> 52) & 0x7FF;

    if ((u & 0x1FFFFFFF) != 0x10000000 or e == 0x7FF or (xy_z - xy == z and xy_z - z == xy)) {
        return @floatCast(xy_z);
    } else {
        // TODO: Handle inexact case with double-rounding
        return @floatCast(xy_z);
    }
}

/// NOTE: Upstream fma.c has been rewritten completely to raise fp exceptions more accurately.
pub fn fma(x: f64, y: f64, z: f64) callconv(.C) f64 {
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
    const ex = x1.exponent;
    const xs = x1.significand;
    const x2 = math.frexp(y);
    const ey = x2.exponent;
    const ys = x2.significand;
    const x3 = math.frexp(z);
    const ez = x3.exponent;
    var zs = x3.significand;

    var spread = ex + ey - ez;
    if (spread <= 53 * 2) {
        zs = math.scalbn(zs, -spread);
    } else {
        zs = math.copysign(math.floatMin(f64), zs);
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

pub fn __fmax(a: f80, b: f80, c: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(fmaq(a, b, c));
}

/// Fused multiply-add: Compute x * y + z with a single rounding error.
///
/// We use scaling to avoid overflow/underflow, along with the
/// canonical precision-doubling technique adapted from:
///
///      Dekker, T.  A Floating-Point Technique for Extending the
///      Available Precision.  Numer. Math. 18, 224-242 (1971).
pub fn fmaq(x: f128, y: f128, z: f128) callconv(.C) f128 {
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
    const ex = x1.exponent;
    const xs = x1.significand;
    const x2 = math.frexp(y);
    const ey = x2.exponent;
    const ys = x2.significand;
    const x3 = math.frexp(z);
    const ez = x3.exponent;
    var zs = x3.significand;

    var spread = ex + ey - ez;
    if (spread <= 113 * 2) {
        zs = math.scalbn(zs, -spread);
    } else {
        zs = math.copysign(math.floatMin(f128), zs);
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

pub fn fmal(x: c_longdouble, y: c_longdouble, z: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __fmah(x, y, z),
        32 => return fmaf(x, y, z),
        64 => return fma(x, y, z),
        80 => return __fmax(x, y, z),
        128 => return fmaq(x, y, z),
        else => @compileError("unreachable"),
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
    const la = a - ha;

    p = b * split;
    var hb = b - p;
    hb += p;
    const lb = b - hb;

    p = ha * hb;
    const q = ha * lb + la * hb;

    ret.hi = p + q;
    ret.lo = p - ret.hi + q + la * lb;
    return ret;
}

fn add_adjusted(a: f64, b: f64) f64 {
    var sum = dd_add(a, b);
    if (sum.lo != 0) {
        var uhii: u64 = @bitCast(sum.hi);
        if (uhii & 1 == 0) {
            // hibits += copysign(1.0, sum.hi, sum.lo)
            const uloi: u64 = @bitCast(sum.lo);
            uhii += 1 - ((uhii ^ uloi) >> 62);
            sum.hi = @bitCast(uhii);
        }
    }
    return sum.hi;
}

fn add_and_denorm(a: f64, b: f64, scale: i32) f64 {
    var sum = dd_add(a, b);
    if (sum.lo != 0) {
        var uhii: u64 = @bitCast(sum.hi);
        const bits_lost = -@as(i32, @intCast((uhii >> 52) & 0x7FF)) - scale + 1;
        if ((bits_lost != 1) == (uhii & 1 != 0)) {
            const uloi: u64 = @bitCast(sum.lo);
            uhii += 1 - (((uhii ^ uloi) >> 62) & 2);
            sum.hi = @bitCast(uhii);
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
        var uhii: u128 = @bitCast(sum.hi);
        if (uhii & 1 == 0) {
            // hibits += copysign(1.0, sum.hi, sum.lo)
            const uloi: u128 = @bitCast(sum.lo);
            uhii += 1 - ((uhii ^ uloi) >> 126);
            sum.hi = @bitCast(uhii);
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
        var uhii: u128 = @bitCast(sum.hi);
        const bits_lost = -@as(i32, @intCast((uhii >> 112) & 0x7FFF)) - scale + 1;
        if ((bits_lost != 1) == (uhii & 1 != 0)) {
            const uloi: u128 = @bitCast(sum.lo);
            uhii += 1 - (((uhii ^ uloi) >> 126) & 2);
            sum.hi = @bitCast(uhii);
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
    const la = a - ha;

    p = b * split;
    var hb = b - p;
    hb += p;
    const lb = b - hb;

    p = ha * hb;
    const q = ha * lb + la * hb;

    ret.hi = p + q;
    ret.lo = p - ret.hi + q + la * lb;
    return ret;
}

test "32" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f32, fmaf(0.0, 5.0, 9.124), 9.124, epsilon));
    try expect(math.approxEqAbs(f32, fmaf(0.2, 5.0, 9.124), 10.124, epsilon));
    try expect(math.approxEqAbs(f32, fmaf(0.8923, 5.0, 9.124), 13.5855, epsilon));
    try expect(math.approxEqAbs(f32, fmaf(1.5, 5.0, 9.124), 16.624, epsilon));
    try expect(math.approxEqAbs(f32, fmaf(37.45, 5.0, 9.124), 196.374004, epsilon));
    try expect(math.approxEqAbs(f32, fmaf(89.123, 5.0, 9.124), 454.739005, epsilon));
    try expect(math.approxEqAbs(f32, fmaf(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

test "64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, fma(0.0, 5.0, 9.124), 9.124, epsilon));
    try expect(math.approxEqAbs(f64, fma(0.2, 5.0, 9.124), 10.124, epsilon));
    try expect(math.approxEqAbs(f64, fma(0.8923, 5.0, 9.124), 13.5855, epsilon));
    try expect(math.approxEqAbs(f64, fma(1.5, 5.0, 9.124), 16.624, epsilon));
    try expect(math.approxEqAbs(f64, fma(37.45, 5.0, 9.124), 196.374, epsilon));
    try expect(math.approxEqAbs(f64, fma(89.123, 5.0, 9.124), 454.739, epsilon));
    try expect(math.approxEqAbs(f64, fma(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

test "128" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f128, fmaq(0.0, 5.0, 9.124), 9.124, epsilon));
    try expect(math.approxEqAbs(f128, fmaq(0.2, 5.0, 9.124), 10.124, epsilon));
    try expect(math.approxEqAbs(f128, fmaq(0.8923, 5.0, 9.124), 13.5855, epsilon));
    try expect(math.approxEqAbs(f128, fmaq(1.5, 5.0, 9.124), 16.624, epsilon));
    try expect(math.approxEqAbs(f128, fmaq(37.45, 5.0, 9.124), 196.374, epsilon));
    try expect(math.approxEqAbs(f128, fmaq(89.123, 5.0, 9.124), 454.739, epsilon));
    try expect(math.approxEqAbs(f128, fmaq(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

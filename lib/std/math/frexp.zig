// Ported from musl, which is MIT licensed:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/frexpl.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/frexpf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/frexp.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

pub fn Frexp(comptime T: type) type {
    return struct {
        significand: T,
        exponent: i32,
    };
}

/// Breaks x into a normalized fraction and an integral power of two.
/// f == frac * 2^exp, with |frac| in the interval [0.5, 1).
///
/// Special Cases:
///  - frexp(+-0)   = +-0, 0
///  - frexp(+-inf) = +-inf, 0
///  - frexp(nan)   = nan, undefined
pub fn frexp(x: anytype) Frexp(@TypeOf(x)) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => frexp32(x),
        f64 => frexp64(x),
        f128 => frexp128(x),
        else => @compileError("frexp not implemented for " ++ @typeName(T)),
    };
}

// TODO: unify all these implementations using generics

fn frexp32(x: f32) Frexp(f32) {
    var result: Frexp(f32) = undefined;

    var y = @as(u32, @bitCast(x));
    const e = @as(i32, @intCast(y >> 23)) & 0xFF;

    if (e == 0) {
        if (x != 0) {
            // subnormal
            result = frexp32(x * 0x1.0p64);
            result.exponent -= 64;
        } else {
            // frexp(+-0) = (+-0, 0)
            result.significand = x;
            result.exponent = 0;
        }
        return result;
    } else if (e == 0xFF) {
        // frexp(nan) = (nan, undefined)
        result.significand = x;
        result.exponent = undefined;

        // frexp(+-inf) = (+-inf, 0)
        if (math.isInf(x)) {
            result.exponent = 0;
        }

        return result;
    }

    result.exponent = e - 0x7E;
    y &= 0x807FFFFF;
    y |= 0x3F000000;
    result.significand = @as(f32, @bitCast(y));
    return result;
}

fn frexp64(x: f64) Frexp(f64) {
    var result: Frexp(f64) = undefined;

    var y = @as(u64, @bitCast(x));
    const e = @as(i32, @intCast(y >> 52)) & 0x7FF;

    if (e == 0) {
        if (x != 0) {
            // subnormal
            result = frexp64(x * 0x1.0p64);
            result.exponent -= 64;
        } else {
            // frexp(+-0) = (+-0, 0)
            result.significand = x;
            result.exponent = 0;
        }
        return result;
    } else if (e == 0x7FF) {
        // frexp(nan) = (nan, undefined)
        result.significand = x;
        result.exponent = undefined;

        // frexp(+-inf) = (+-inf, 0)
        if (math.isInf(x)) {
            result.exponent = 0;
        }

        return result;
    }

    result.exponent = e - 0x3FE;
    y &= 0x800FFFFFFFFFFFFF;
    y |= 0x3FE0000000000000;
    result.significand = @as(f64, @bitCast(y));
    return result;
}

fn frexp128(x: f128) Frexp(f128) {
    var result: Frexp(f128) = undefined;

    var y = @as(u128, @bitCast(x));
    const e = @as(i32, @intCast(y >> 112)) & 0x7FFF;

    if (e == 0) {
        if (x != 0) {
            // subnormal
            result = frexp128(x * 0x1.0p120);
            result.exponent -= 120;
        } else {
            // frexp(+-0) = (+-0, 0)
            result.significand = x;
            result.exponent = 0;
        }
        return result;
    } else if (e == 0x7FFF) {
        // frexp(nan) = (nan, undefined)
        result.significand = x;
        result.exponent = undefined;

        // frexp(+-inf) = (+-inf, 0)
        if (math.isInf(x)) {
            result.exponent = 0;
        }

        return result;
    }

    result.exponent = e - 0x3FFE;
    y &= 0x8000FFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    y |= 0x3FFE0000000000000000000000000000;
    result.significand = @as(f128, @bitCast(y));
    return result;
}

test "type dispatch" {
    const a = frexp(@as(f32, 1.3));
    const b = frexp32(1.3);
    try expect(a.significand == b.significand and a.exponent == b.exponent);

    const c = frexp(@as(f64, 1.3));
    const d = frexp64(1.3);
    try expect(c.significand == d.significand and c.exponent == d.exponent);

    const e = frexp(@as(f128, 1.3));
    const f = frexp128(1.3);
    try expect(e.significand == f.significand and e.exponent == f.exponent);
}

test "32" {
    const epsilon = 0.000001;
    var r: Frexp(f32) = undefined;

    r = frexp32(1.3);
    try expect(math.approxEqAbs(f32, r.significand, 0.65, epsilon) and r.exponent == 1);

    r = frexp32(78.0234);
    try expect(math.approxEqAbs(f32, r.significand, 0.609558, epsilon) and r.exponent == 7);
}

test "64" {
    const epsilon = 0.000001;
    var r: Frexp(f64) = undefined;

    r = frexp64(1.3);
    try expect(math.approxEqAbs(f64, r.significand, 0.65, epsilon) and r.exponent == 1);

    r = frexp64(78.0234);
    try expect(math.approxEqAbs(f64, r.significand, 0.609558, epsilon) and r.exponent == 7);
}

test "128" {
    const epsilon = 0.000001;
    var r: Frexp(f128) = undefined;

    r = frexp128(1.3);
    try expect(math.approxEqAbs(f128, r.significand, 0.65, epsilon) and r.exponent == 1);

    r = frexp128(78.0234);
    try expect(math.approxEqAbs(f128, r.significand, 0.609558, epsilon) and r.exponent == 7);
}

test "32 special" {
    var r: Frexp(f32) = undefined;

    r = frexp32(0.0);
    try expect(r.significand == 0.0 and r.exponent == 0);

    r = frexp32(-0.0);
    try expect(r.significand == -0.0 and r.exponent == 0);

    r = frexp32(math.inf(f32));
    try expect(math.isPositiveInf(r.significand) and r.exponent == 0);

    r = frexp32(-math.inf(f32));
    try expect(math.isNegativeInf(r.significand) and r.exponent == 0);

    r = frexp32(math.nan(f32));
    try expect(math.isNan(r.significand));
}

test "64 special" {
    var r: Frexp(f64) = undefined;

    r = frexp64(0.0);
    try expect(r.significand == 0.0 and r.exponent == 0);

    r = frexp64(-0.0);
    try expect(r.significand == -0.0 and r.exponent == 0);

    r = frexp64(math.inf(f64));
    try expect(math.isPositiveInf(r.significand) and r.exponent == 0);

    r = frexp64(-math.inf(f64));
    try expect(math.isNegativeInf(r.significand) and r.exponent == 0);

    r = frexp64(math.nan(f64));
    try expect(math.isNan(r.significand));
}

test "128 special" {
    var r: Frexp(f128) = undefined;

    r = frexp128(0.0);
    try expect(r.significand == 0.0 and r.exponent == 0);

    r = frexp128(-0.0);
    try expect(r.significand == -0.0 and r.exponent == 0);

    r = frexp128(math.inf(f128));
    try expect(math.isPositiveInf(r.significand) and r.exponent == 0);

    r = frexp128(-math.inf(f128));
    try expect(math.isNegativeInf(r.significand) and r.exponent == 0);

    r = frexp128(math.nan(f128));
    try expect(math.isNan(r.significand));
}

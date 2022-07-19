// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/ldexpf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/ldexp.c

const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const expect = std.testing.expect;

/// Returns x * 2^n.
pub fn ldexp(x: anytype, n: i32) @TypeOf(x) {
    var base = x;
    var shift = n;

    const T = @TypeOf(base);
    const TBits = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);

    const mantissa_bits = math.floatMantissaBits(T);
    const exponent_min = math.floatExponentMin(T);
    const exponent_max = math.floatExponentMax(T);

    const exponent_bias = exponent_max;

    // fix double rounding errors in subnormal ranges
    // https://git.musl-libc.org/cgit/musl/commit/src/math/ldexp.c?id=8c44a060243f04283ca68dad199aab90336141db
    const scale_min_expo = exponent_min + mantissa_bits + 1;
    const scale_min = @bitCast(T, @as(TBits, scale_min_expo + exponent_bias) << mantissa_bits);
    const scale_max = @bitCast(T, @intCast(TBits, exponent_max + exponent_bias) << mantissa_bits);

    // scale `shift` within floating point limits, if possible
    // second pass is possible due to subnormal range
    // third pass always results in +/-0.0 or +/-inf
    if (shift > exponent_max) {
        base *= scale_max;
        shift -= exponent_max;
        if (shift > exponent_max) {
            base *= scale_max;
            shift -= exponent_max;
            if (shift > exponent_max) shift = exponent_max;
        }
    } else if (shift < exponent_min) {
        base *= scale_min;
        shift -= scale_min_expo;
        if (shift < exponent_min) {
            base *= scale_min;
            shift -= scale_min_expo;
            if (shift < exponent_min) shift = exponent_min;
        }
    }

    return base * @bitCast(T, @intCast(TBits, shift + exponent_bias) << mantissa_bits);
}

test "math.ldexp" {
    // TODO derive the various constants here with new maths API

    // basic usage
    try expect(ldexp(@as(f16, 1.5), 4) == 24.0);
    try expect(ldexp(@as(f32, 1.5), 4) == 24.0);
    try expect(ldexp(@as(f64, 1.5), 4) == 24.0);
    try expect(ldexp(@as(f128, 1.5), 4) == 24.0);

    // subnormals
    try expect(math.isNormal(ldexp(@as(f16, 1.0), -14)));
    try expect(!math.isNormal(ldexp(@as(f16, 1.0), -15)));
    try expect(math.isNormal(ldexp(@as(f32, 1.0), -126)));
    try expect(!math.isNormal(ldexp(@as(f32, 1.0), -127)));
    try expect(math.isNormal(ldexp(@as(f64, 1.0), -1022)));
    try expect(!math.isNormal(ldexp(@as(f64, 1.0), -1023)));
    try expect(math.isNormal(ldexp(@as(f128, 1.0), -16382)));
    try expect(!math.isNormal(ldexp(@as(f128, 1.0), -16383)));
    // unreliable due to lack of native f16 support, see talk on PR #8733
    // try expect(ldexp(@as(f16, 0x1.1FFp-1), -14 - 9) == math.floatTrueMin(f16));
    try expect(ldexp(@as(f32, 0x1.3FFFFFp-1), -126 - 22) == math.floatTrueMin(f32));
    try expect(ldexp(@as(f64, 0x1.7FFFFFFFFFFFFp-1), -1022 - 51) == math.floatTrueMin(f64));
    try expect(ldexp(@as(f128, 0x1.7FFFFFFFFFFFFFFFFFFFFFFFFFFFp-1), -16382 - 111) == math.floatTrueMin(f128));

    // float limits
    try expect(ldexp(math.floatMax(f32), -128 - 149) > 0.0);
    try expect(ldexp(math.floatMax(f32), -128 - 149 - 1) == 0.0);
    try expect(!math.isPositiveInf(ldexp(math.floatTrueMin(f16), 15 + 24)));
    try expect(math.isPositiveInf(ldexp(math.floatTrueMin(f16), 15 + 24 + 1)));
    try expect(!math.isPositiveInf(ldexp(math.floatTrueMin(f32), 127 + 149)));
    try expect(math.isPositiveInf(ldexp(math.floatTrueMin(f32), 127 + 149 + 1)));
    try expect(!math.isPositiveInf(ldexp(math.floatTrueMin(f64), 1023 + 1074)));
    try expect(math.isPositiveInf(ldexp(math.floatTrueMin(f64), 1023 + 1074 + 1)));
    try expect(!math.isPositiveInf(ldexp(math.floatTrueMin(f128), 16383 + 16494)));
    try expect(math.isPositiveInf(ldexp(math.floatTrueMin(f128), 16383 + 16494 + 1)));
}

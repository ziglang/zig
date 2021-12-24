// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/sinf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/sin.c
//
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

const kernel = @import("__trig.zig");
const __rem_pio2 = @import("__rem_pio2.zig").__rem_pio2;
const __rem_pio2f = @import("__rem_pio2f.zig").__rem_pio2f;

/// Returns the sine of the radian value x.
///
/// Special Cases:
///  - sin(+-0)   = +-0
///  - sin(+-inf) = nan
///  - sin(nan)   = nan
pub fn sin(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => sin32(x),
        f64 => sin64(x),
        else => @compileError("sin not implemented for " ++ @typeName(T)),
    };
}

fn sin32(x: f32) f32 {
    // Small multiples of pi/2 rounded to double precision.
    const s1pio2: f64 = 1.0 * math.pi / 2.0; // 0x3FF921FB, 0x54442D18
    const s2pio2: f64 = 2.0 * math.pi / 2.0; // 0x400921FB, 0x54442D18
    const s3pio2: f64 = 3.0 * math.pi / 2.0; // 0x4012D97C, 0x7F3321D2
    const s4pio2: f64 = 4.0 * math.pi / 2.0; // 0x401921FB, 0x54442D18

    var ix = @bitCast(u32, x);
    const sign = ix >> 31 != 0;
    ix &= 0x7fffffff;

    if (ix <= 0x3f490fda) { // |x| ~<= pi/4
        if (ix < 0x39800000) { // |x| < 2**-12
            // raise inexact if x!=0 and underflow if subnormal
            math.doNotOptimizeAway(if (ix < 0x00800000) x / 0x1p120 else x + 0x1p120);
            return x;
        }
        return kernel.__sindf(x);
    }
    if (ix <= 0x407b53d1) { // |x| ~<= 5*pi/4
        if (ix <= 0x4016cbe3) { // |x| ~<= 3pi/4
            if (sign) {
                return -kernel.__cosdf(x + s1pio2);
            } else {
                return kernel.__cosdf(x - s1pio2);
            }
        }
        return kernel.__sindf(if (sign) -(x + s2pio2) else -(x - s2pio2));
    }
    if (ix <= 0x40e231d5) { // |x| ~<= 9*pi/4
        if (ix <= 0x40afeddf) { // |x| ~<= 7*pi/4
            if (sign) {
                return kernel.__cosdf(x + s3pio2);
            } else {
                return -kernel.__cosdf(x - s3pio2);
            }
        }
        return kernel.__sindf(if (sign) x + s4pio2 else x - s4pio2);
    }

    // sin(Inf or NaN) is NaN
    if (ix >= 0x7f800000) {
        return x - x;
    }

    var y: f64 = undefined;
    const n = __rem_pio2f(x, &y);
    return switch (n & 3) {
        0 => kernel.__sindf(y),
        1 => kernel.__cosdf(y),
        2 => kernel.__sindf(-y),
        else => -kernel.__cosdf(y),
    };
}

fn sin64(x: f64) f64 {
    var ix = @bitCast(u64, x) >> 32;
    ix &= 0x7fffffff;

    // |x| ~< pi/4
    if (ix <= 0x3fe921fb) {
        if (ix < 0x3e500000) { // |x| < 2**-26
            // raise inexact if x != 0 and underflow if subnormal
            math.doNotOptimizeAway(if (ix < 0x00100000) x / 0x1p120 else x + 0x1p120);
            return x;
        }
        return kernel.__sin(x, 0.0, 0);
    }

    // sin(Inf or NaN) is NaN
    if (ix >= 0x7ff00000) {
        return x - x;
    }

    var y: [2]f64 = undefined;
    const n = __rem_pio2(x, &y);
    return switch (n & 3) {
        0 => kernel.__sin(y[0], y[1], 1),
        1 => kernel.__cos(y[0], y[1]),
        2 => -kernel.__sin(y[0], y[1], 1),
        else => -kernel.__cos(y[0], y[1]),
    };
}

test "math.sin" {
    try expect(sin(@as(f32, 0.0)) == sin32(0.0));
    try expect(sin(@as(f64, 0.0)) == sin64(0.0));
    try expect(comptime (math.sin(@as(f64, 2))) == math.sin(@as(f64, 2)));
}

test "math.sin32" {
    const epsilon = 0.00001;

    try expect(math.approxEqAbs(f32, sin32(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f32, sin32(0.2), 0.198669, epsilon));
    try expect(math.approxEqAbs(f32, sin32(0.8923), 0.778517, epsilon));
    try expect(math.approxEqAbs(f32, sin32(1.5), 0.997495, epsilon));
    try expect(math.approxEqAbs(f32, sin32(-1.5), -0.997495, epsilon));
    try expect(math.approxEqAbs(f32, sin32(37.45), -0.246544, epsilon));
    try expect(math.approxEqAbs(f32, sin32(89.123), 0.916166, epsilon));
}

test "math.sin64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, sin64(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f64, sin64(0.2), 0.198669, epsilon));
    try expect(math.approxEqAbs(f64, sin64(0.8923), 0.778517, epsilon));
    try expect(math.approxEqAbs(f64, sin64(1.5), 0.997495, epsilon));
    try expect(math.approxEqAbs(f64, sin64(-1.5), -0.997495, epsilon));
    try expect(math.approxEqAbs(f64, sin64(37.45), -0.246543, epsilon));
    try expect(math.approxEqAbs(f64, sin64(89.123), 0.916166, epsilon));
}

test "math.sin32.special" {
    try expect(sin32(0.0) == 0.0);
    try expect(sin32(-0.0) == -0.0);
    try expect(math.isNan(sin32(math.inf(f32))));
    try expect(math.isNan(sin32(-math.inf(f32))));
    try expect(math.isNan(sin32(math.nan(f32))));
}

test "math.sin64.special" {
    try expect(sin64(0.0) == 0.0);
    try expect(sin64(-0.0) == -0.0);
    try expect(math.isNan(sin64(math.inf(f64))));
    try expect(math.isNan(sin64(-math.inf(f64))));
    try expect(math.isNan(sin64(math.nan(f64))));
}

test "math.sin32 #9901" {
    const float = @bitCast(f32, @as(u32, 0b11100011111111110000000000000000));
    _ = std.math.sin(float);
}

test "math.sin64 #9901" {
    const float = @bitCast(f64, @as(u64, 0b1111111101000001000000001111110111111111100000000000000000000001));
    _ = std.math.sin(float);
}

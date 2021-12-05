// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/cosf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/cos.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

const kernel = @import("__trig.zig");
const __rem_pio2 = @import("__rem_pio2.zig").__rem_pio2;
const __rem_pio2f = @import("__rem_pio2f.zig").__rem_pio2f;

/// Returns the cosine of the radian value x.
///
/// Special Cases:
///  - cos(+-inf) = nan
///  - cos(nan)   = nan
pub fn cos(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => cos32(x),
        f64 => cos64(x),
        else => @compileError("cos not implemented for " ++ @typeName(T)),
    };
}

fn cos32(x: f32) f32 {
    // Small multiples of pi/2 rounded to double precision.
    const c1pio2: f64 = 1.0 * math.pi / 2.0; // 0x3FF921FB, 0x54442D18
    const c2pio2: f64 = 2.0 * math.pi / 2.0; // 0x400921FB, 0x54442D18
    const c3pio2: f64 = 3.0 * math.pi / 2.0; // 0x4012D97C, 0x7F3321D2
    const c4pio2: f64 = 4.0 * math.pi / 2.0; // 0x401921FB, 0x54442D18

    var ix = @bitCast(u32, x);
    const sign = ix >> 31 != 0;
    ix &= 0x7fffffff;

    if (ix <= 0x3f490fda) { // |x| ~<= pi/4
        if (ix < 0x39800000) { // |x| < 2**-12
            // raise inexact if x != 0
            math.doNotOptimizeAway(x + 0x1p120);
            return 1.0;
        }
        return kernel.__cosdf(x);
    }
    if (ix <= 0x407b53d1) { // |x| ~<= 5*pi/4
        if (ix > 0x4016cbe3) { // |x|  ~> 3*pi/4
            return -kernel.__cosdf(if (sign) x + c2pio2 else x - c2pio2);
        } else {
            if (sign) {
                return kernel.__sindf(x + c1pio2);
            } else {
                return kernel.__sindf(c1pio2 - x);
            }
        }
    }
    if (ix <= 0x40e231d5) { // |x| ~<= 9*pi/4
        if (ix > 0x40afeddf) { // |x| ~> 7*pi/4
            return kernel.__cosdf(if (sign) x + c4pio2 else x - c4pio2);
        } else {
            if (sign) {
                return kernel.__sindf(-x - c3pio2);
            } else {
                return kernel.__sindf(x - c3pio2);
            }
        }
    }

    // cos(Inf or NaN) is NaN
    if (ix >= 0x7f800000) {
        return x - x;
    }

    var y: f64 = undefined;
    const n = __rem_pio2f(x, &y);
    return switch (n & 3) {
        0 => kernel.__cosdf(y),
        1 => kernel.__sindf(-y),
        2 => -kernel.__cosdf(y),
        else => kernel.__sindf(y),
    };
}

fn cos64(x: f64) f64 {
    var ix = @bitCast(u64, x) >> 32;
    ix &= 0x7fffffff;

    // |x| ~< pi/4
    if (ix <= 0x3fe921fb) {
        if (ix < 0x3e46a09e) { // |x| < 2**-27 * sqrt(2)
            // raise inexact if x!=0
            math.doNotOptimizeAway(x + 0x1p120);
            return 1.0;
        }
        return kernel.__cos(x, 0);
    }

    // cos(Inf or NaN) is NaN
    if (ix >= 0x7ff00000) {
        return x - x;
    }

    var y: [2]f64 = undefined;
    const n = __rem_pio2(x, &y);
    return switch (n & 3) {
        0 => kernel.__cos(y[0], y[1]),
        1 => -kernel.__sin(y[0], y[1], 1),
        2 => -kernel.__cos(y[0], y[1]),
        else => kernel.__sin(y[0], y[1], 1),
    };
}

test "math.cos" {
    try expect(cos(@as(f32, 0.0)) == cos32(0.0));
    try expect(cos(@as(f64, 0.0)) == cos64(0.0));
}

test "math.cos32" {
    const epsilon = 0.00001;

    try expect(math.approxEqAbs(f32, cos32(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f32, cos32(0.2), 0.980067, epsilon));
    try expect(math.approxEqAbs(f32, cos32(0.8923), 0.627623, epsilon));
    try expect(math.approxEqAbs(f32, cos32(1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f32, cos32(-1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f32, cos32(37.45), 0.969132, epsilon));
    try expect(math.approxEqAbs(f32, cos32(89.123), 0.400798, epsilon));
}

test "math.cos64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, cos64(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f64, cos64(0.2), 0.980067, epsilon));
    try expect(math.approxEqAbs(f64, cos64(0.8923), 0.627623, epsilon));
    try expect(math.approxEqAbs(f64, cos64(1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f64, cos64(-1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f64, cos64(37.45), 0.969132, epsilon));
    try expect(math.approxEqAbs(f64, cos64(89.123), 0.40080, epsilon));
}

test "math.cos32.special" {
    try expect(math.isNan(cos32(math.inf(f32))));
    try expect(math.isNan(cos32(-math.inf(f32))));
    try expect(math.isNan(cos32(math.nan(f32))));
}

test "math.cos64.special" {
    try expect(math.isNan(cos64(math.inf(f64))));
    try expect(math.isNan(cos64(-math.inf(f64))));
    try expect(math.isNan(cos64(math.nan(f64))));
}

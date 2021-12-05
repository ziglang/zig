// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/tanf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/tan.c
// https://golang.org/src/math/tan.go

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

const kernel = @import("__trig.zig");
const __rem_pio2 = @import("__rem_pio2.zig").__rem_pio2;
const __rem_pio2f = @import("__rem_pio2f.zig").__rem_pio2f;

/// Returns the tangent of the radian value x.
///
/// Special Cases:
///  - tan(+-0)   = +-0
///  - tan(+-inf) = nan
///  - tan(nan)   = nan
pub fn tan(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => tan32(x),
        f64 => tan64(x),
        else => @compileError("tan not implemented for " ++ @typeName(T)),
    };
}

fn tan32(x: f32) f32 {
    // Small multiples of pi/2 rounded to double precision.
    const t1pio2: f64 = 1.0 * math.pi / 2.0; // 0x3FF921FB, 0x54442D18
    const t2pio2: f64 = 2.0 * math.pi / 2.0; // 0x400921FB, 0x54442D18
    const t3pio2: f64 = 3.0 * math.pi / 2.0; // 0x4012D97C, 0x7F3321D2
    const t4pio2: f64 = 4.0 * math.pi / 2.0; // 0x401921FB, 0x54442D18

    var ix = @bitCast(u32, x);
    const sign = ix >> 31 != 0;
    ix &= 0x7fffffff;

    if (ix <= 0x3f490fda) { // |x| ~<= pi/4
        if (ix < 0x39800000) { // |x| < 2**-12
            // raise inexact if x!=0 and underflow if subnormal
            math.doNotOptimizeAway(if (ix < 0x00800000) x / 0x1p120 else x + 0x1p120);
            return x;
        }
        return kernel.__tandf(x, false);
    }
    if (ix <= 0x407b53d1) { // |x| ~<= 5*pi/4
        if (ix <= 0x4016cbe3) { // |x| ~<= 3pi/4
            return kernel.__tandf((if (sign) x + t1pio2 else x - t1pio2), true);
        } else {
            return kernel.__tandf((if (sign) x + t2pio2 else x - t2pio2), false);
        }
    }
    if (ix <= 0x40e231d5) { // |x| ~<= 9*pi/4
        if (ix <= 0x40afeddf) { // |x| ~<= 7*pi/4
            return kernel.__tandf((if (sign) x + t3pio2 else x - t3pio2), true);
        } else {
            return kernel.__tandf((if (sign) x + t4pio2 else x - t4pio2), false);
        }
    }

    // tan(Inf or NaN) is NaN
    if (ix >= 0x7f800000) {
        return x - x;
    }

    var y: f64 = undefined;
    const n = __rem_pio2f(x, &y);
    return kernel.__tandf(y, n & 1 != 0);
}

fn tan64(x: f64) f64 {
    var ix = @bitCast(u64, x) >> 32;
    ix &= 0x7fffffff;

    // |x| ~< pi/4
    if (ix <= 0x3fe921fb) {
        if (ix < 0x3e400000) { // |x| < 2**-27
            // raise inexact if x!=0 and underflow if subnormal
            math.doNotOptimizeAway(if (ix < 0x00100000) x / 0x1p120 else x + 0x1p120);
            return x;
        }
        return kernel.__tan(x, 0.0, false);
    }

    // tan(Inf or NaN) is NaN
    if (ix >= 0x7ff00000) {
        return x - x;
    }

    var y: [2]f64 = undefined;
    const n = __rem_pio2(x, &y);
    return kernel.__tan(y[0], y[1], n & 1 != 0);
}

test "math.tan" {
    try expect(tan(@as(f32, 0.0)) == tan32(0.0));
    try expect(tan(@as(f64, 0.0)) == tan64(0.0));
}

test "math.tan32" {
    const epsilon = 0.00001;

    try expect(math.approxEqAbs(f32, tan32(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f32, tan32(0.2), 0.202710, epsilon));
    try expect(math.approxEqAbs(f32, tan32(0.8923), 1.240422, epsilon));
    try expect(math.approxEqAbs(f32, tan32(1.5), 14.101420, epsilon));
    try expect(math.approxEqAbs(f32, tan32(37.45), -0.254397, epsilon));
    try expect(math.approxEqAbs(f32, tan32(89.123), 2.285852, epsilon));
}

test "math.tan64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, tan64(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f64, tan64(0.2), 0.202710, epsilon));
    try expect(math.approxEqAbs(f64, tan64(0.8923), 1.240422, epsilon));
    try expect(math.approxEqAbs(f64, tan64(1.5), 14.101420, epsilon));
    try expect(math.approxEqAbs(f64, tan64(37.45), -0.254397, epsilon));
    try expect(math.approxEqAbs(f64, tan64(89.123), 2.2858376, epsilon));
}

test "math.tan32.special" {
    try expect(tan32(0.0) == 0.0);
    try expect(tan32(-0.0) == -0.0);
    try expect(math.isNan(tan32(math.inf(f32))));
    try expect(math.isNan(tan32(-math.inf(f32))));
    try expect(math.isNan(tan32(math.nan(f32))));
}

test "math.tan64.special" {
    try expect(tan64(0.0) == 0.0);
    try expect(tan64(-0.0) == -0.0);
    try expect(math.isNan(tan64(math.inf(f64))));
    try expect(math.isNan(tan64(-math.inf(f64))));
    try expect(math.isNan(tan64(math.nan(f64))));
}

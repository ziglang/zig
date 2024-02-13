const std = @import("std");
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const common = @import("common.zig");

pub const panic = common.panic;

const trig = @import("trig.zig");
const rem_pio2 = @import("rem_pio2.zig").rem_pio2;
const rem_pio2f = @import("rem_pio2f.zig").rem_pio2f;

comptime {
    @export(__cosh, .{ .name = "__cosh", .linkage = common.linkage, .visibility = common.visibility });
    @export(cosf, .{ .name = "cosf", .linkage = common.linkage, .visibility = common.visibility });
    @export(cos, .{ .name = "cos", .linkage = common.linkage, .visibility = common.visibility });
    @export(__cosx, .{ .name = "__cosx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(cosq, .{ .name = "cosf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(cosq, .{ .name = "cosq", .linkage = common.linkage, .visibility = common.visibility });
    @export(cosl, .{ .name = "cosl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __cosh(a: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(cosf(a));
}

pub fn cosf(x: f32) callconv(.C) f32 {
    // Small multiples of pi/2 rounded to double precision.
    const c1pio2: f64 = 1.0 * math.pi / 2.0; // 0x3FF921FB, 0x54442D18
    const c2pio2: f64 = 2.0 * math.pi / 2.0; // 0x400921FB, 0x54442D18
    const c3pio2: f64 = 3.0 * math.pi / 2.0; // 0x4012D97C, 0x7F3321D2
    const c4pio2: f64 = 4.0 * math.pi / 2.0; // 0x401921FB, 0x54442D18

    var ix: u32 = @bitCast(x);
    const sign = ix >> 31 != 0;
    ix &= 0x7fffffff;

    if (ix <= 0x3f490fda) { // |x| ~<= pi/4
        if (ix < 0x39800000) { // |x| < 2**-12
            // raise inexact if x != 0
            mem.doNotOptimizeAway(x + 0x1p120);
            return 1.0;
        }
        return trig.__cosdf(x);
    }
    if (ix <= 0x407b53d1) { // |x| ~<= 5*pi/4
        if (ix > 0x4016cbe3) { // |x|  ~> 3*pi/4
            return -trig.__cosdf(if (sign) x + c2pio2 else x - c2pio2);
        } else {
            if (sign) {
                return trig.__sindf(x + c1pio2);
            } else {
                return trig.__sindf(c1pio2 - x);
            }
        }
    }
    if (ix <= 0x40e231d5) { // |x| ~<= 9*pi/4
        if (ix > 0x40afeddf) { // |x| ~> 7*pi/4
            return trig.__cosdf(if (sign) x + c4pio2 else x - c4pio2);
        } else {
            if (sign) {
                return trig.__sindf(-x - c3pio2);
            } else {
                return trig.__sindf(x - c3pio2);
            }
        }
    }

    // cos(Inf or NaN) is NaN
    if (ix >= 0x7f800000) {
        return x - x;
    }

    var y: f64 = undefined;
    const n = rem_pio2f(x, &y);
    return switch (n & 3) {
        0 => trig.__cosdf(y),
        1 => trig.__sindf(-y),
        2 => -trig.__cosdf(y),
        else => trig.__sindf(y),
    };
}

pub fn cos(x: f64) callconv(.C) f64 {
    var ix = @as(u64, @bitCast(x)) >> 32;
    ix &= 0x7fffffff;

    // |x| ~< pi/4
    if (ix <= 0x3fe921fb) {
        if (ix < 0x3e46a09e) { // |x| < 2**-27 * sqrt(2)
            // raise inexact if x!=0
            mem.doNotOptimizeAway(x + 0x1p120);
            return 1.0;
        }
        return trig.__cos(x, 0);
    }

    // cos(Inf or NaN) is NaN
    if (ix >= 0x7ff00000) {
        return x - x;
    }

    var y: [2]f64 = undefined;
    const n = rem_pio2(x, &y);
    return switch (n & 3) {
        0 => trig.__cos(y[0], y[1]),
        1 => -trig.__sin(y[0], y[1], 1),
        2 => -trig.__cos(y[0], y[1]),
        else => trig.__sin(y[0], y[1], 1),
    };
}

pub fn __cosx(a: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(cosq(a));
}

pub fn cosq(a: f128) callconv(.C) f128 {
    // TODO: more correct implementation
    return cos(@floatCast(a));
}

pub fn cosl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __cosh(x),
        32 => return cosf(x),
        64 => return cos(x),
        80 => return __cosx(x),
        128 => return cosq(x),
        else => @compileError("unreachable"),
    }
}

test "cos32" {
    const epsilon = 0.00001;

    try expect(math.approxEqAbs(f32, cosf(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f32, cosf(0.2), 0.980067, epsilon));
    try expect(math.approxEqAbs(f32, cosf(0.8923), 0.627623, epsilon));
    try expect(math.approxEqAbs(f32, cosf(1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f32, cosf(-1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f32, cosf(37.45), 0.969132, epsilon));
    try expect(math.approxEqAbs(f32, cosf(89.123), 0.400798, epsilon));
}

test "cos64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, cos(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f64, cos(0.2), 0.980067, epsilon));
    try expect(math.approxEqAbs(f64, cos(0.8923), 0.627623, epsilon));
    try expect(math.approxEqAbs(f64, cos(1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f64, cos(-1.5), 0.070737, epsilon));
    try expect(math.approxEqAbs(f64, cos(37.45), 0.969132, epsilon));
    try expect(math.approxEqAbs(f64, cos(89.123), 0.40080, epsilon));
}

test "cos32.special" {
    try expect(math.isNan(cosf(math.inf(f32))));
    try expect(math.isNan(cosf(-math.inf(f32))));
    try expect(math.isNan(cosf(math.nan(f32))));
}

test "cos64.special" {
    try expect(math.isNan(cos(math.inf(f64))));
    try expect(math.isNan(cos(-math.inf(f64))));
    try expect(math.isNan(cos(math.nan(f64))));
}

//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/sinf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/sin.c

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const common = @import("common.zig");

const trig = @import("trig.zig");
const rem_pio2 = @import("rem_pio2.zig").rem_pio2;
const rem_pio2f = @import("rem_pio2f.zig").rem_pio2f;

pub const panic = common.panic;

comptime {
    @export(__sinh, .{ .name = "__sinh", .linkage = common.linkage, .visibility = common.visibility });
    @export(sinf, .{ .name = "sinf", .linkage = common.linkage, .visibility = common.visibility });
    @export(sin, .{ .name = "sin", .linkage = common.linkage, .visibility = common.visibility });
    @export(__sinx, .{ .name = "__sinx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(sinq, .{ .name = "sinf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(sinq, .{ .name = "sinq", .linkage = common.linkage, .visibility = common.visibility });
    @export(sinl, .{ .name = "sinl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __sinh(x: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(sinf(x));
}

pub fn sinf(x: f32) callconv(.C) f32 {
    // Small multiples of pi/2 rounded to double precision.
    const s1pio2: f64 = 1.0 * math.pi / 2.0; // 0x3FF921FB, 0x54442D18
    const s2pio2: f64 = 2.0 * math.pi / 2.0; // 0x400921FB, 0x54442D18
    const s3pio2: f64 = 3.0 * math.pi / 2.0; // 0x4012D97C, 0x7F3321D2
    const s4pio2: f64 = 4.0 * math.pi / 2.0; // 0x401921FB, 0x54442D18

    var ix: u32 = @bitCast(x);
    const sign = ix >> 31 != 0;
    ix &= 0x7fffffff;

    if (ix <= 0x3f490fda) { // |x| ~<= pi/4
        if (ix < 0x39800000) { // |x| < 2**-12
            // raise inexact if x!=0 and underflow if subnormal
            mem.doNotOptimizeAway(if (ix < 0x00800000) x / 0x1p120 else x + 0x1p120);
            return x;
        }
        return trig.__sindf(x);
    }
    if (ix <= 0x407b53d1) { // |x| ~<= 5*pi/4
        if (ix <= 0x4016cbe3) { // |x| ~<= 3pi/4
            if (sign) {
                return -trig.__cosdf(x + s1pio2);
            } else {
                return trig.__cosdf(x - s1pio2);
            }
        }
        return trig.__sindf(if (sign) -(x + s2pio2) else -(x - s2pio2));
    }
    if (ix <= 0x40e231d5) { // |x| ~<= 9*pi/4
        if (ix <= 0x40afeddf) { // |x| ~<= 7*pi/4
            if (sign) {
                return trig.__cosdf(x + s3pio2);
            } else {
                return -trig.__cosdf(x - s3pio2);
            }
        }
        return trig.__sindf(if (sign) x + s4pio2 else x - s4pio2);
    }

    // sin(Inf or NaN) is NaN
    if (ix >= 0x7f800000) {
        return x - x;
    }

    var y: f64 = undefined;
    const n = rem_pio2f(x, &y);
    return switch (n & 3) {
        0 => trig.__sindf(y),
        1 => trig.__cosdf(y),
        2 => trig.__sindf(-y),
        else => -trig.__cosdf(y),
    };
}

pub fn sin(x: f64) callconv(.C) f64 {
    var ix = @as(u64, @bitCast(x)) >> 32;
    ix &= 0x7fffffff;

    // |x| ~< pi/4
    if (ix <= 0x3fe921fb) {
        if (ix < 0x3e500000) { // |x| < 2**-26
            // raise inexact if x != 0 and underflow if subnormal
            mem.doNotOptimizeAway(if (ix < 0x00100000) x / 0x1p120 else x + 0x1p120);
            return x;
        }
        return trig.__sin(x, 0.0, 0);
    }

    // sin(Inf or NaN) is NaN
    if (ix >= 0x7ff00000) {
        return x - x;
    }

    var y: [2]f64 = undefined;
    const n = rem_pio2(x, &y);
    return switch (n & 3) {
        0 => trig.__sin(y[0], y[1], 1),
        1 => trig.__cos(y[0], y[1]),
        2 => -trig.__sin(y[0], y[1], 1),
        else => -trig.__cos(y[0], y[1]),
    };
}

pub fn __sinx(x: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(sinq(x));
}

pub fn sinq(x: f128) callconv(.C) f128 {
    // TODO: more correct implementation
    return sin(@floatCast(x));
}

pub fn sinl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __sinh(x),
        32 => return sinf(x),
        64 => return sin(x),
        80 => return __sinx(x),
        128 => return sinq(x),
        else => @compileError("unreachable"),
    }
}

test "sin32" {
    const epsilon = 0.00001;

    try expect(math.approxEqAbs(f32, sinf(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f32, sinf(0.2), 0.198669, epsilon));
    try expect(math.approxEqAbs(f32, sinf(0.8923), 0.778517, epsilon));
    try expect(math.approxEqAbs(f32, sinf(1.5), 0.997495, epsilon));
    try expect(math.approxEqAbs(f32, sinf(-1.5), -0.997495, epsilon));
    try expect(math.approxEqAbs(f32, sinf(37.45), -0.246544, epsilon));
    try expect(math.approxEqAbs(f32, sinf(89.123), 0.916166, epsilon));
}

test "sin64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, sin(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f64, sin(0.2), 0.198669, epsilon));
    try expect(math.approxEqAbs(f64, sin(0.8923), 0.778517, epsilon));
    try expect(math.approxEqAbs(f64, sin(1.5), 0.997495, epsilon));
    try expect(math.approxEqAbs(f64, sin(-1.5), -0.997495, epsilon));
    try expect(math.approxEqAbs(f64, sin(37.45), -0.246543, epsilon));
    try expect(math.approxEqAbs(f64, sin(89.123), 0.916166, epsilon));
}

test "sin32.special" {
    try expect(sinf(0.0) == 0.0);
    try expect(sinf(-0.0) == -0.0);
    try expect(math.isNan(sinf(math.inf(f32))));
    try expect(math.isNan(sinf(-math.inf(f32))));
    try expect(math.isNan(sinf(math.nan(f32))));
}

test "sin64.special" {
    try expect(sin(0.0) == 0.0);
    try expect(sin(-0.0) == -0.0);
    try expect(math.isNan(sin(math.inf(f64))));
    try expect(math.isNan(sin(-math.inf(f64))));
    try expect(math.isNan(sin(math.nan(f64))));
}

test "sin32 #9901" {
    const float: f32 = @bitCast(@as(u32, 0b11100011111111110000000000000000));
    _ = sinf(float);
}

test "sin64 #9901" {
    const float: f64 = @bitCast(@as(u64, 0b1111111101000001000000001111110111111111100000000000000000000001));
    _ = sin(float);
}

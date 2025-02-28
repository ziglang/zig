//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/tanf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/tan.c
//! https://golang.org/src/math/tan.go

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;

const kernel = @import("trig.zig");
const rem_pio2 = @import("rem_pio2.zig").rem_pio2;
const rem_pio2f = @import("rem_pio2f.zig").rem_pio2f;

const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__tanh, .{ .name = "__tanh", .linkage = common.linkage, .visibility = common.visibility });
    @export(&tanf, .{ .name = "tanf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&tan, .{ .name = "tan", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__tanx, .{ .name = "__tanx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(&tanq, .{ .name = "tanf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&tanq, .{ .name = "tanq", .linkage = common.linkage, .visibility = common.visibility });
    @export(&tanl, .{ .name = "tanl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __tanh(x: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(tanf(x));
}

pub fn tanf(x: f32) callconv(.C) f32 {
    // Small multiples of pi/2 rounded to double precision.
    const t1pio2: f64 = 1.0 * math.pi / 2.0; // 0x3FF921FB, 0x54442D18
    const t2pio2: f64 = 2.0 * math.pi / 2.0; // 0x400921FB, 0x54442D18
    const t3pio2: f64 = 3.0 * math.pi / 2.0; // 0x4012D97C, 0x7F3321D2
    const t4pio2: f64 = 4.0 * math.pi / 2.0; // 0x401921FB, 0x54442D18

    var ix: u32 = @bitCast(x);
    const sign = ix >> 31 != 0;
    ix &= 0x7fffffff;

    if (ix <= 0x3f490fda) { // |x| ~<= pi/4
        if (ix < 0x39800000) { // |x| < 2**-12
            // raise inexact if x!=0 and underflow if subnormal
            if (common.want_float_exceptions) mem.doNotOptimizeAway(if (ix < 0x00800000) x / 0x1p120 else x + 0x1p120);
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
    const n = rem_pio2f(x, &y);
    return kernel.__tandf(y, n & 1 != 0);
}

pub fn tan(x: f64) callconv(.C) f64 {
    var ix = @as(u64, @bitCast(x)) >> 32;
    ix &= 0x7fffffff;

    // |x| ~< pi/4
    if (ix <= 0x3fe921fb) {
        if (ix < 0x3e400000) { // |x| < 2**-27
            // raise inexact if x!=0 and underflow if subnormal
            if (common.want_float_exceptions) mem.doNotOptimizeAway(if (ix < 0x00100000) x / 0x1p120 else x + 0x1p120);
            return x;
        }
        return kernel.__tan(x, 0.0, false);
    }

    // tan(Inf or NaN) is NaN
    if (ix >= 0x7ff00000) {
        return x - x;
    }

    var y: [2]f64 = undefined;
    const n = rem_pio2(x, &y);
    return kernel.__tan(y[0], y[1], n & 1 != 0);
}

pub fn __tanx(x: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(tanq(x));
}

pub fn tanq(x: f128) callconv(.C) f128 {
    // TODO: more correct implementation
    return tan(@floatCast(x));
}

pub fn tanl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return __tanh(x),
        32 => return tanf(x),
        64 => return tan(x),
        80 => return __tanx(x),
        128 => return tanq(x),
        else => @compileError("unreachable"),
    }
}

test "tan" {
    try expect(tan(@as(f32, 0.0)) == tanf(0.0));
    try expect(tan(@as(f64, 0.0)) == tan(0.0));
}

test "tan32" {
    const epsilon = 0.00001;

    try expect(math.approxEqAbs(f32, tanf(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f32, tanf(0.2), 0.202710, epsilon));
    try expect(math.approxEqAbs(f32, tanf(0.8923), 1.240422, epsilon));
    try expect(math.approxEqAbs(f32, tanf(1.5), 14.101420, epsilon));
    try expect(math.approxEqAbs(f32, tanf(37.45), -0.254397, epsilon));
    try expect(math.approxEqAbs(f32, tanf(89.123), 2.285852, epsilon));
}

test "tan64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, tan(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f64, tan(0.2), 0.202710, epsilon));
    try expect(math.approxEqAbs(f64, tan(0.8923), 1.240422, epsilon));
    try expect(math.approxEqAbs(f64, tan(1.5), 14.101420, epsilon));
    try expect(math.approxEqAbs(f64, tan(37.45), -0.254397, epsilon));
    try expect(math.approxEqAbs(f64, tan(89.123), 2.2858376, epsilon));
}

test "tan32.special" {
    try expect(tanf(0.0) == 0.0);
    try expect(tanf(-0.0) == -0.0);
    try expect(math.isNan(tanf(math.inf(f32))));
    try expect(math.isNan(tanf(-math.inf(f32))));
    try expect(math.isNan(tanf(math.nan(f32))));
}

test "tan64.special" {
    try expect(tan(0.0) == 0.0);
    try expect(tan(-0.0) == -0.0);
    try expect(math.isNan(tan(math.inf(f64))));
    try expect(math.isNan(tan(-math.inf(f64))));
    try expect(math.isNan(tan(math.nan(f64))));
}

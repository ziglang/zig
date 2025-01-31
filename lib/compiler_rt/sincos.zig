const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const math = std.math;
const mem = std.mem;
const trig = @import("trig.zig");
const rem_pio2 = @import("rem_pio2.zig").rem_pio2;
const rem_pio2f = @import("rem_pio2f.zig").rem_pio2f;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__sincosh, .{ .name = "__sincosh", .linkage = common.linkage, .visibility = common.visibility });
    @export(&sincosf, .{ .name = "sincosf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&sincos, .{ .name = "sincos", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__sincosx, .{ .name = "__sincosx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(&sincosq, .{ .name = "sincosf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&sincosq, .{ .name = "sincosq", .linkage = common.linkage, .visibility = common.visibility });
    @export(&sincosl, .{ .name = "sincosl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __sincosh(x: f16, r_sin: *f16, r_cos: *f16) callconv(.C) void {
    // TODO: more efficient implementation
    var big_sin: f32 = undefined;
    var big_cos: f32 = undefined;
    sincosf(x, &big_sin, &big_cos);
    r_sin.* = @as(f16, @floatCast(big_sin));
    r_cos.* = @as(f16, @floatCast(big_cos));
}

pub fn sincosf(x: f32, r_sin: *f32, r_cos: *f32) callconv(.C) void {
    const sc1pio2: f64 = 1.0 * math.pi / 2.0; // 0x3FF921FB, 0x54442D18
    const sc2pio2: f64 = 2.0 * math.pi / 2.0; // 0x400921FB, 0x54442D18
    const sc3pio2: f64 = 3.0 * math.pi / 2.0; // 0x4012D97C, 0x7F3321D2
    const sc4pio2: f64 = 4.0 * math.pi / 2.0; // 0x401921FB, 0x54442D18

    const pre_ix = @as(u32, @bitCast(x));
    const sign = pre_ix >> 31 != 0;
    const ix = pre_ix & 0x7fffffff;

    // |x| ~<= pi/4
    if (ix <= 0x3f490fda) {
        // |x| < 2**-12
        if (ix < 0x39800000) {
            // raise inexact if x!=0 and underflow if subnormal
            if (common.want_float_exceptions) mem.doNotOptimizeAway(if (ix < 0x00100000) x / 0x1p120 else x + 0x1p120);
            r_sin.* = x;
            r_cos.* = 1.0;
            return;
        }
        r_sin.* = trig.__sindf(x);
        r_cos.* = trig.__cosdf(x);
        return;
    }

    // |x| ~<= 5*pi/4
    if (ix <= 0x407b53d1) {
        // |x| ~<= 3pi/4
        if (ix <= 0x4016cbe3) {
            if (sign) {
                r_sin.* = -trig.__cosdf(x + sc1pio2);
                r_cos.* = trig.__sindf(x + sc1pio2);
            } else {
                r_sin.* = trig.__cosdf(sc1pio2 - x);
                r_cos.* = trig.__sindf(sc1pio2 - x);
            }
            return;
        }
        //  -sin(x+c) is not correct if x+c could be 0: -0 vs +0
        r_sin.* = -trig.__sindf(if (sign) x + sc2pio2 else x - sc2pio2);
        r_cos.* = -trig.__cosdf(if (sign) x + sc2pio2 else x - sc2pio2);
        return;
    }

    // |x| ~<= 9*pi/4
    if (ix <= 0x40e231d5) {
        // |x| ~<= 7*pi/4
        if (ix <= 0x40afeddf) {
            if (sign) {
                r_sin.* = trig.__cosdf(x + sc3pio2);
                r_cos.* = -trig.__sindf(x + sc3pio2);
            } else {
                r_sin.* = -trig.__cosdf(x - sc3pio2);
                r_cos.* = trig.__sindf(x - sc3pio2);
            }
            return;
        }
        r_sin.* = trig.__sindf(if (sign) x + sc4pio2 else x - sc4pio2);
        r_cos.* = trig.__cosdf(if (sign) x + sc4pio2 else x - sc4pio2);
        return;
    }

    // sin(Inf or NaN) is NaN
    if (ix >= 0x7f800000) {
        const result = x - x;
        r_sin.* = result;
        r_cos.* = result;
        return;
    }

    // general argument reduction needed
    var y: f64 = undefined;
    const n = rem_pio2f(x, &y);
    const s = trig.__sindf(y);
    const c = trig.__cosdf(y);
    switch (n & 3) {
        0 => {
            r_sin.* = s;
            r_cos.* = c;
        },
        1 => {
            r_sin.* = c;
            r_cos.* = -s;
        },
        2 => {
            r_sin.* = -s;
            r_cos.* = -c;
        },
        else => {
            r_sin.* = -c;
            r_cos.* = s;
        },
    }
}

pub fn sincos(x: f64, r_sin: *f64, r_cos: *f64) callconv(.C) void {
    const ix = @as(u32, @truncate(@as(u64, @bitCast(x)) >> 32)) & 0x7fffffff;

    // |x| ~< pi/4
    if (ix <= 0x3fe921fb) {
        // if |x| < 2**-27 * sqrt(2)
        if (ix < 0x3e46a09e) {
            // raise inexact if x != 0 and underflow if subnormal
            if (common.want_float_exceptions) mem.doNotOptimizeAway(if (ix < 0x00100000) x / 0x1p120 else x + 0x1p120);
            r_sin.* = x;
            r_cos.* = 1.0;
            return;
        }
        r_sin.* = trig.__sin(x, 0.0, 0);
        r_cos.* = trig.__cos(x, 0.0);
        return;
    }

    // sincos(Inf or NaN) is NaN
    if (ix >= 0x7ff00000) {
        const result = x - x;
        r_sin.* = result;
        r_cos.* = result;
        return;
    }

    // argument reduction needed
    var y: [2]f64 = undefined;
    const n = rem_pio2(x, &y);
    const s = trig.__sin(y[0], y[1], 1);
    const c = trig.__cos(y[0], y[1]);
    switch (n & 3) {
        0 => {
            r_sin.* = s;
            r_cos.* = c;
        },
        1 => {
            r_sin.* = c;
            r_cos.* = -s;
        },
        2 => {
            r_sin.* = -s;
            r_cos.* = -c;
        },
        else => {
            r_sin.* = -c;
            r_cos.* = s;
        },
    }
}

pub fn __sincosx(x: f80, r_sin: *f80, r_cos: *f80) callconv(.C) void {
    // TODO: more efficient implementation
    //return sincos_generic(f80, x, r_sin, r_cos);
    var big_sin: f128 = undefined;
    var big_cos: f128 = undefined;
    sincosq(x, &big_sin, &big_cos);
    r_sin.* = @as(f80, @floatCast(big_sin));
    r_cos.* = @as(f80, @floatCast(big_cos));
}

pub fn sincosq(x: f128, r_sin: *f128, r_cos: *f128) callconv(.C) void {
    // TODO: more correct implementation
    //return sincos_generic(f128, x, r_sin, r_cos);
    var small_sin: f64 = undefined;
    var small_cos: f64 = undefined;
    sincos(@as(f64, @floatCast(x)), &small_sin, &small_cos);
    r_sin.* = small_sin;
    r_cos.* = small_cos;
}

pub fn sincosl(x: c_longdouble, r_sin: *c_longdouble, r_cos: *c_longdouble) callconv(.C) void {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return __sincosh(x, r_sin, r_cos),
        32 => return sincosf(x, r_sin, r_cos),
        64 => return sincos(x, r_sin, r_cos),
        80 => return __sincosx(x, r_sin, r_cos),
        128 => return sincosq(x, r_sin, r_cos),
        else => @compileError("unreachable"),
    }
}

pub const rem_pio2_generic = @compileError("TODO");

/// Ported from musl sincosl.c. Needs the following dependencies to be complete:
/// * rem_pio2_generic ported from __rem_pio2l.c
/// * trig.sin_generic ported from __sinl.c
/// * trig.cos_generic ported from __cosl.c
inline fn sincos_generic(comptime F: type, x: F, r_sin: *F, r_cos: *F) void {
    const sc1pio4: F = 1.0 * math.pi / 4.0;
    const bits = @typeInfo(F).float.bits;
    const I = std.meta.Int(.unsigned, bits);
    const ix = @as(I, @bitCast(x)) & (math.maxInt(I) >> 1);
    const se: u16 = @truncate(ix >> (bits - 16));

    if (se == 0x7fff) {
        const result = x - x;
        r_sin.* = result;
        r_cos.* = result;
        return;
    }

    if (@as(F, @bitCast(ix)) < sc1pio4) {
        if (se < 0x3fff - math.floatFractionalBits(F) - 1) {
            // raise underflow if subnormal
            if (se == 0) {
                if (common.want_float_exceptions) mem.doNotOptimizeAway(x * 0x1p-120);
            }
            r_sin.* = x;
            // raise inexact if x!=0
            r_cos.* = 1.0 + x;
            return;
        }
        r_sin.* = trig.sin_generic(F, x, 0, 0);
        r_cos.* = trig.cos_generic(F, x, 0);
        return;
    }

    var y: [2]F = undefined;
    const n = rem_pio2_generic(F, x, &y);
    const s = trig.sin_generic(F, y[0], y[1], 1);
    const c = trig.cos_generic(F, y[0], y[1]);
    switch (n & 3) {
        0 => {
            r_sin.* = s;
            r_cos.* = c;
        },
        1 => {
            r_sin.* = c;
            r_cos.* = -s;
        },
        2 => {
            r_sin.* = -s;
            r_cos.* = -c;
        },
        else => {
            r_sin.* = -c;
            r_cos.* = s;
        },
    }
}

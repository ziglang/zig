// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/expf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/exp.c

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__exph, .{ .name = "__exph", .linkage = common.linkage, .visibility = common.visibility });
    @export(expf, .{ .name = "expf", .linkage = common.linkage, .visibility = common.visibility });
    @export(exp, .{ .name = "exp", .linkage = common.linkage, .visibility = common.visibility });
    @export(__expx, .{ .name = "__expx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(expq, .{ .name = "expf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(expq, .{ .name = "expq", .linkage = common.linkage, .visibility = common.visibility });
    @export(expl, .{ .name = "expl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __exph(a: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(expf(a));
}

pub fn expf(x_: f32) callconv(.C) f32 {
    const half = [_]f32{ 0.5, -0.5 };
    const ln2hi = 6.9314575195e-1;
    const ln2lo = 1.4286067653e-6;
    const invln2 = 1.4426950216e+0;
    const P1 = 1.6666625440e-1;
    const P2 = -2.7667332906e-3;

    var x = x_;
    var hx: u32 = @bitCast(x);
    const sign: i32 = @intCast(hx >> 31);
    hx &= 0x7FFFFFFF;

    if (math.isNan(x)) {
        return x;
    }

    // |x| >= -87.33655 or nan
    if (hx >= 0x42AEAC50) {
        // nan
        if (hx > 0x7F800000) {
            return x;
        }
        // x >= 88.722839
        if (hx >= 0x42b17218 and sign == 0) {
            return x * 0x1.0p127;
        }
        if (sign != 0) {
            mem.doNotOptimizeAway(-0x1.0p-149 / x); // overflow
            // x <= -103.972084
            if (hx >= 0x42CFF1B5) {
                return 0;
            }
        }
    }

    var k: i32 = undefined;
    var hi: f32 = undefined;
    var lo: f32 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3EB17218) {
        // |x| > 1.5 * ln2
        if (hx > 0x3F851592) {
            k = @intFromFloat(invln2 * x + half[@intCast(sign)]);
        } else {
            k = 1 - sign - sign;
        }

        const fk: f32 = @floatFromInt(k);
        hi = x - fk * ln2hi;
        lo = fk * ln2lo;
        x = hi - lo;
    }
    // |x| > 2^(-14)
    else if (hx > 0x39000000) {
        k = 0;
        hi = x;
        lo = 0;
    } else {
        mem.doNotOptimizeAway(0x1.0p127 + x); // inexact
        return 1 + x;
    }

    const xx = x * x;
    const c = x - xx * (P1 + xx * P2);
    const y = 1 + (x * c / (2 - c) - lo + hi);

    if (k == 0) {
        return y;
    } else {
        return math.scalbn(y, k);
    }
}

pub fn exp(x_: f64) callconv(.C) f64 {
    const half = [_]f64{ 0.5, -0.5 };
    const ln2hi: f64 = 6.93147180369123816490e-01;
    const ln2lo: f64 = 1.90821492927058770002e-10;
    const invln2: f64 = 1.44269504088896338700e+00;
    const P1: f64 = 1.66666666666666019037e-01;
    const P2: f64 = -2.77777777770155933842e-03;
    const P3: f64 = 6.61375632143793436117e-05;
    const P4: f64 = -1.65339022054652515390e-06;
    const P5: f64 = 4.13813679705723846039e-08;

    var x = x_;
    const ux: u64 = @bitCast(x);
    var hx = ux >> 32;
    const sign: i32 = @intCast(hx >> 31);
    hx &= 0x7FFFFFFF;

    if (math.isNan(x)) {
        return x;
    }

    // |x| >= 708.39 or nan
    if (hx >= 0x4086232B) {
        // nan
        if (hx > 0x7FF00000) {
            return x;
        }
        if (x > 709.782712893383973096) {
            // overflow if x != inf
            if (!math.isInf(x)) {
                math.raiseOverflow();
            }
            return math.inf(f64);
        }
        if (x < -708.39641853226410622) {
            // underflow if x != -inf
            // mem.doNotOptimizeAway(@as(f32, -0x1.0p-149 / x));
            if (x < -745.13321910194110842) {
                return 0;
            }
        }
    }

    // argument reduction
    var k: i32 = undefined;
    var hi: f64 = undefined;
    var lo: f64 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3FD62E42) {
        // |x| >= 1.5 * ln2
        if (hx > 0x3FF0A2B2) {
            k = @intFromFloat(invln2 * x + half[@intCast(sign)]);
        } else {
            k = 1 - sign - sign;
        }

        const dk: f64 = @floatFromInt(k);
        hi = x - dk * ln2hi;
        lo = dk * ln2lo;
        x = hi - lo;
    }
    // |x| > 2^(-28)
    else if (hx > 0x3E300000) {
        k = 0;
        hi = x;
        lo = 0;
    } else {
        // inexact if x != 0
        // mem.doNotOptimizeAway(0x1.0p1023 + x);
        return 1 + x;
    }

    const xx = x * x;
    const c = x - xx * (P1 + xx * (P2 + xx * (P3 + xx * (P4 + xx * P5))));
    const y = 1 + (x * c / (2 - c) - lo + hi);

    if (k == 0) {
        return y;
    } else {
        return math.scalbn(y, k);
    }
}

pub fn __expx(a: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(expq(a));
}

pub fn expq(a: f128) callconv(.C) f128 {
    // TODO: more correct implementation
    return exp(@floatCast(a));
}

pub fn expl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __exph(x),
        32 => return expf(x),
        64 => return exp(x),
        80 => return __expx(x),
        128 => return expq(x),
        else => @compileError("unreachable"),
    }
}

test "exp32" {
    const epsilon = 0.000001;

    try expect(expf(0.0) == 1.0);
    try expect(math.approxEqAbs(f32, expf(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f32, expf(0.2), 1.221403, epsilon));
    try expect(math.approxEqAbs(f32, expf(0.8923), 2.440737, epsilon));
    try expect(math.approxEqAbs(f32, expf(1.5), 4.481689, epsilon));
}

test "exp64" {
    const epsilon = 0.000001;

    try expect(exp(0.0) == 1.0);
    try expect(math.approxEqAbs(f64, exp(0.0), 1.0, epsilon));
    try expect(math.approxEqAbs(f64, exp(0.2), 1.221403, epsilon));
    try expect(math.approxEqAbs(f64, exp(0.8923), 2.440737, epsilon));
    try expect(math.approxEqAbs(f64, exp(1.5), 4.481689, epsilon));
}

test "exp32.special" {
    try expect(math.isPositiveInf(expf(math.inf(f32))));
    try expect(math.isNan(expf(math.nan(f32))));
}

test "exp64.special" {
    try expect(math.isPositiveInf(exp(math.inf(f64))));
    try expect(math.isNan(exp(math.nan(f64))));
}

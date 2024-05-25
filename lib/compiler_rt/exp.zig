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
const expectEqual = std.testing.expectEqual;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(&__exph, .{ .name = "__exph", .linkage = common.linkage, .visibility = common.visibility });
    @export(&expf, .{ .name = "expf", .linkage = common.linkage, .visibility = common.visibility });
    @export(&exp, .{ .name = "exp", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__expx, .{ .name = "__expx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(&expq, .{ .name = "expf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&expq, .{ .name = "expq", .linkage = common.linkage, .visibility = common.visibility });
    @export(&expl, .{ .name = "expl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __exph(a: f16) callconv(.c) f16 {
    // TODO: more efficient implementation
    return @floatCast(expf(a));
}

pub fn expf(x_: f32) callconv(.c) f32 {
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
            if (common.want_float_exceptions) mem.doNotOptimizeAway(-0x1.0p-149 / x); // overflow
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
        if (common.want_float_exceptions) mem.doNotOptimizeAway(0x1.0p127 + x); // inexact
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

pub fn exp(x_: f64) callconv(.c) f64 {
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
            // if (common.want_float_exceptions) mem.doNotOptimizeAway(@as(f32, -0x1.0p-149 / x));
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
        // if (common.want_float_exceptions) mem.doNotOptimizeAway(0x1.0p1023 + x);
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

pub fn __expx(a: f80) callconv(.c) f80 {
    // TODO: more efficient implementation
    return @floatCast(expq(a));
}

pub fn expq(a: f128) callconv(.c) f128 {
    // TODO: more correct implementation
    return exp(@floatCast(a));
}

pub fn expl(x: c_longdouble) callconv(.c) c_longdouble {
    switch (@typeInfo(c_longdouble).float.bits) {
        16 => return __exph(x),
        32 => return expf(x),
        64 => return exp(x),
        80 => return __expx(x),
        128 => return expq(x),
        else => @compileError("unreachable"),
    }
}

test "expf() special" {
    try expectEqual(expf(0.0), 1.0);
    try expectEqual(expf(-0.0), 1.0);
    try expectEqual(expf(1.0), math.e);
    try expectEqual(expf(math.ln2), 2.0);
    try expectEqual(expf(math.inf(f32)), math.inf(f32));
    try expectEqual(expf(-math.inf(f32)), 0.0);
    try expect(math.isNan(expf(math.nan(f32))));
    try expect(math.isNan(expf(math.snan(f32))));
}

test "expf() sanity" {
    try expectEqual(expf(-0x1.0223a0p+3), 0x1.490320p-12);
    try expectEqual(expf(0x1.161868p+2), 0x1.34712ap+6);
    try expectEqual(expf(-0x1.0c34b4p+3), 0x1.e06b1ap-13);
    try expectEqual(expf(-0x1.a206f0p+2), 0x1.7dd484p-10);
    try expectEqual(expf(0x1.288bbcp+3), 0x1.4abc80p+13);
    try expectEqual(expf(0x1.52efd0p-1), 0x1.f04a9cp+0);
    try expectEqual(expf(-0x1.a05cc8p-2), 0x1.54f1e0p-1);
    try expectEqual(expf(0x1.1f9efap-1), 0x1.c0f628p+0);
    try expectEqual(expf(0x1.8c5db0p-1), 0x1.1599b2p+1);
    try expectEqual(expf(-0x1.5b86eap-1), 0x1.03b572p-1);
    try expectEqual(expf(-0x1.57f25cp+2), 0x1.2fbea2p-8);
    try expectEqual(expf(0x1.c7d310p+3), 0x1.76eefp+20);
    try expectEqual(expf(0x1.19be70p+4), 0x1.52d3dep+25);
    try expectEqual(expf(-0x1.ab6d70p+3), 0x1.a88adep-20);
    try expectEqual(expf(-0x1.5ac18ep+2), 0x1.22b328p-8);
    try expectEqual(expf(-0x1.925982p-1), 0x1.d2acc0p-2);
    try expectEqual(expf(0x1.7221cep+3), 0x1.9c2ceap+16);
    try expectEqual(expf(0x1.11a0d4p+4), 0x1.980ee6p+24);
    try expectEqual(expf(-0x1.ae41a2p+1), 0x1.1c28d0p-5);
    try expectEqual(expf(-0x1.329154p+4), 0x1.47ef94p-28);
}

test "expf() boundary" {
    try expectEqual(expf(0x1.62e42ep+6), 0x1.ffff08p+127); // The last value before the result gets infinite
    try expectEqual(expf(0x1.62e430p+6), math.inf(f32)); // The first value that gives inf
    try expectEqual(expf(0x1.fffffep+127), math.inf(f32)); // Max input value
    try expectEqual(expf(0x1p-149), 1.0); // Min positive input value
    try expectEqual(expf(-0x1p-149), 1.0); // Min negative input value
    try expectEqual(expf(0x1p-126), 1.0); // First positive subnormal input
    try expectEqual(expf(-0x1p-126), 1.0); // First negative subnormal input
    try expectEqual(expf(-0x1.9fe368p+6), 0x1p-149); // The last value before the result flushes to zero
    try expectEqual(expf(-0x1.9fe36ap+6), 0.0); // The first value at which the result flushes to zero
    try expectEqual(expf(-0x1.5d589ep+6), 0x1.00004cp-126); // The last value before the result flushes to subnormal
    try expectEqual(expf(-0x1.5d58a0p+6), 0x1.ffff98p-127); // The first value for which the result flushes to subnormal

}

test "exp() special" {
    try expectEqual(exp(0.0), 1.0);
    try expectEqual(exp(-0.0), 1.0);
    // TODO: Accuracy error - off in the last bit in 64-bit, disagreeing with GCC
    // try expectEqual(exp(1.0), math.e);
    try expectEqual(exp(math.ln2), 2.0);
    try expectEqual(exp(math.inf(f64)), math.inf(f64));
    try expectEqual(exp(-math.inf(f64)), 0.0);
    try expect(math.isNan(exp(math.nan(f64))));
    try expect(math.isNan(exp(math.snan(f64))));
}

test "exp() sanity" {
    try expectEqual(exp(-0x1.02239f3c6a8f1p+3), 0x1.490327ea61235p-12);
    try expectEqual(exp(0x1.161868e18bc67p+2), 0x1.34712ed238c04p+6);
    try expectEqual(exp(-0x1.0c34b3e01e6e7p+3), 0x1.e06b1b6c18e64p-13);
    try expectEqual(exp(-0x1.a206f0a19dcc4p+2), 0x1.7dd47f810e68cp-10);
    try expectEqual(exp(0x1.288bbb0d6a1e6p+3), 0x1.4abc77496e07ep+13);
    try expectEqual(exp(0x1.52efd0cd80497p-1), 0x1.f04a9c1080500p+0);
    try expectEqual(exp(-0x1.a05cc754481d1p-2), 0x1.54f1e0fd3ea0dp-1);
    try expectEqual(exp(0x1.1f9ef934745cbp-1), 0x1.c0f6266a6a547p+0);
    try expectEqual(exp(0x1.8c5db097f7442p-1), 0x1.1599b1d4a25fbp+1);
    try expectEqual(exp(-0x1.5b86ea8118a0ep-1), 0x1.03b5728a00229p-1);
    try expectEqual(exp(-0x1.57f25b2b5006dp+2), 0x1.2fbea6a01cab9p-8);
    try expectEqual(exp(0x1.c7d30fb825911p+3), 0x1.76eeed45a0634p+20);
    try expectEqual(exp(0x1.19be709de7505p+4), 0x1.52d3eb7be6844p+25);
    try expectEqual(exp(-0x1.ab6d6fba96889p+3), 0x1.a88ae12f985d6p-20);
    try expectEqual(exp(-0x1.5ac18e27084ddp+2), 0x1.22b327da9cca6p-8);
    try expectEqual(exp(-0x1.925981b093c41p-1), 0x1.d2acc046b55f7p-2);
    try expectEqual(exp(0x1.7221cd18455f5p+3), 0x1.9c2cde8699cfbp+16);
    try expectEqual(exp(0x1.11a0d4a51b239p+4), 0x1.980ef612ff182p+24);
    try expectEqual(exp(-0x1.ae41a1079de4dp+1), 0x1.1c28d16bb3222p-5);
    try expectEqual(exp(-0x1.329153103b871p+4), 0x1.47efa6ddd0d22p-28);
}

test "exp() boundary" {
    try expectEqual(exp(0x1.62e42fefa39efp+9), 0x1.fffffffffff2ap+1023); // The last value before the result gets infinite
    try expectEqual(exp(0x1.62e42fefa39f0p+9), math.inf(f64)); // The first value that gives inf
    try expectEqual(exp(0x1.fffffffffffffp+1023), math.inf(f64)); // Max input value
    try expectEqual(exp(0x1p-1074), 1.0); // Min positive input value
    try expectEqual(exp(-0x1p-1074), 1.0); // Min negative input value
    try expectEqual(exp(0x1p-1022), 1.0); // First positive subnormal input
    try expectEqual(exp(-0x1p-1022), 1.0); // First negative subnormal input
    try expectEqual(exp(-0x1.74910d52d3051p+9), 0x1p-1074); // The last value before the result flushes to zero
    try expectEqual(exp(-0x1.74910d52d3052p+9), 0.0); // The first value at which the result flushes to zero
    try expectEqual(exp(-0x1.6232bdd7abcd2p+9), 0x1.000000000007cp-1022); // The last value before the result flushes to subnormal
    try expectEqual(exp(-0x1.6232bdd7abcd3p+9), 0x1.ffffffffffcf8p-1023); // The first value for which the result flushes to subnormal
}

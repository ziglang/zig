//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/lnf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/ln.c

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const testing = std.testing;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__logh, .{ .name = "__logh", .linkage = common.linkage, .visibility = common.visibility });
    @export(logf, .{ .name = "logf", .linkage = common.linkage, .visibility = common.visibility });
    @export(log, .{ .name = "log", .linkage = common.linkage, .visibility = common.visibility });
    @export(__logx, .{ .name = "__logx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(logq, .{ .name = "logf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(logq, .{ .name = "logq", .linkage = common.linkage, .visibility = common.visibility });
    @export(logl, .{ .name = "logl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __logh(a: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(logf(a));
}

pub fn logf(x_: f32) callconv(.C) f32 {
    const ln2_hi: f32 = 6.9313812256e-01;
    const ln2_lo: f32 = 9.0580006145e-06;
    const Lg1: f32 = 0xaaaaaa.0p-24;
    const Lg2: f32 = 0xccce13.0p-25;
    const Lg3: f32 = 0x91e9ee.0p-25;
    const Lg4: f32 = 0xf89e26.0p-26;

    var x = x_;
    var ix: u32 = @bitCast(x);
    var k: i32 = 0;

    // x < 2^(-126)
    if (ix < 0x00800000 or ix >> 31 != 0) {
        // log(+-0) = -inf
        if (ix << 1 == 0) {
            return -math.inf(f32);
        }
        // log(-#) = nan
        if (ix >> 31 != 0) {
            return math.nan(f32);
        }

        // subnormal, scale x
        k -= 25;
        x *= 0x1.0p25;
        ix = @bitCast(x);
    } else if (ix >= 0x7F800000) {
        return x;
    } else if (ix == 0x3F800000) {
        return 0;
    }

    // x into [sqrt(2) / 2, sqrt(2)]
    ix += 0x3F800000 - 0x3F3504F3;
    k += @as(i32, @intCast(ix >> 23)) - 0x7F;
    ix = (ix & 0x007FFFFF) + 0x3F3504F3;
    x = @bitCast(ix);

    const f = x - 1.0;
    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * Lg4);
    const t2 = z * (Lg1 + w * Lg3);
    const R = t2 + t1;
    const hfsq = 0.5 * f * f;
    const dk: f32 = @floatFromInt(k);

    return s * (hfsq + R) + dk * ln2_lo - hfsq + f + dk * ln2_hi;
}

pub fn log(x_: f64) callconv(.C) f64 {
    const ln2_hi: f64 = 6.93147180369123816490e-01;
    const ln2_lo: f64 = 1.90821492927058770002e-10;
    const Lg1: f64 = 6.666666666666735130e-01;
    const Lg2: f64 = 3.999999999940941908e-01;
    const Lg3: f64 = 2.857142874366239149e-01;
    const Lg4: f64 = 2.222219843214978396e-01;
    const Lg5: f64 = 1.818357216161805012e-01;
    const Lg6: f64 = 1.531383769920937332e-01;
    const Lg7: f64 = 1.479819860511658591e-01;

    var x = x_;
    var ix: u64 = @bitCast(x);
    var hx: u32 = @intCast(ix >> 32);
    var k: i32 = 0;

    if (hx < 0x00100000 or hx >> 31 != 0) {
        // log(+-0) = -inf
        if (ix << 1 == 0) {
            return -math.inf(f64);
        }
        // log(-#) = nan
        if (hx >> 31 != 0) {
            return math.nan(f64);
        }

        // subnormal, scale x
        k -= 54;
        x *= 0x1.0p54;
        hx = @intCast(@as(u64, @bitCast(ix)) >> 32);
    } else if (hx >= 0x7FF00000) {
        return x;
    } else if (hx == 0x3FF00000 and ix << 32 == 0) {
        return 0;
    }

    // x into [sqrt(2) / 2, sqrt(2)]
    hx += 0x3FF00000 - 0x3FE6A09E;
    k += @as(i32, @intCast(hx >> 20)) - 0x3FF;
    hx = (hx & 0x000FFFFF) + 0x3FE6A09E;
    ix = (@as(u64, hx) << 32) | (ix & 0xFFFFFFFF);
    x = @bitCast(ix);

    const f = x - 1.0;
    const hfsq = 0.5 * f * f;
    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * (Lg4 + w * Lg6));
    const t2 = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7)));
    const R = t2 + t1;
    const dk: f64 = @floatFromInt(k);

    return s * (hfsq + R) + dk * ln2_lo - hfsq + f + dk * ln2_hi;
}

pub fn __logx(a: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(logq(a));
}

pub fn logq(a: f128) callconv(.C) f128 {
    // TODO: more correct implementation
    return log(@floatCast(a));
}

pub fn logl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __logh(x),
        32 => return logf(x),
        64 => return log(x),
        80 => return __logx(x),
        128 => return logq(x),
        else => @compileError("unreachable"),
    }
}

test "ln32" {
    const epsilon = 0.000001;

    try testing.expect(math.approxEqAbs(f32, logf(0.2), -1.609438, epsilon));
    try testing.expect(math.approxEqAbs(f32, logf(0.8923), -0.113953, epsilon));
    try testing.expect(math.approxEqAbs(f32, logf(1.5), 0.405465, epsilon));
    try testing.expect(math.approxEqAbs(f32, logf(37.45), 3.623007, epsilon));
    try testing.expect(math.approxEqAbs(f32, logf(89.123), 4.490017, epsilon));
    try testing.expect(math.approxEqAbs(f32, logf(123123.234375), 11.720941, epsilon));
}

test "ln64" {
    const epsilon = 0.000001;

    try testing.expect(math.approxEqAbs(f64, log(0.2), -1.609438, epsilon));
    try testing.expect(math.approxEqAbs(f64, log(0.8923), -0.113953, epsilon));
    try testing.expect(math.approxEqAbs(f64, log(1.5), 0.405465, epsilon));
    try testing.expect(math.approxEqAbs(f64, log(37.45), 3.623007, epsilon));
    try testing.expect(math.approxEqAbs(f64, log(89.123), 4.490017, epsilon));
    try testing.expect(math.approxEqAbs(f64, log(123123.234375), 11.720941, epsilon));
}

test "ln32.special" {
    try testing.expect(math.isPositiveInf(logf(math.inf(f32))));
    try testing.expect(math.isNegativeInf(logf(0.0)));
    try testing.expect(math.isNan(logf(-1.0)));
    try testing.expect(math.isNan(logf(math.nan(f32))));
}

test "ln64.special" {
    try testing.expect(math.isPositiveInf(log(math.inf(f64))));
    try testing.expect(math.isNegativeInf(log(0.0)));
    try testing.expect(math.isNan(log(-1.0)));
    try testing.expect(math.isNan(log(math.nan(f64))));
}

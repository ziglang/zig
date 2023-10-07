//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/math/log2f.c
//! https://git.musl-libc.org/cgit/musl/tree/src/math/log2.c

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;
const arch = builtin.cpu.arch;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__log2h, .{ .name = "__log2h", .linkage = common.linkage, .visibility = common.visibility });
    @export(log2f, .{ .name = "log2f", .linkage = common.linkage, .visibility = common.visibility });
    @export(log2, .{ .name = "log2", .linkage = common.linkage, .visibility = common.visibility });
    @export(__log2x, .{ .name = "__log2x", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(log2q, .{ .name = "log2f128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(log2q, .{ .name = "log2q", .linkage = common.linkage, .visibility = common.visibility });
    @export(log2l, .{ .name = "log2l", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __log2h(a: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(log2f(a));
}

pub fn log2f(x_: f32) callconv(.C) f32 {
    const ivln2hi: f32 = 1.4428710938e+00;
    const ivln2lo: f32 = -1.7605285393e-04;
    const Lg1: f32 = 0xaaaaaa.0p-24;
    const Lg2: f32 = 0xccce13.0p-25;
    const Lg3: f32 = 0x91e9ee.0p-25;
    const Lg4: f32 = 0xf89e26.0p-26;

    var x = x_;
    var u: u32 = @bitCast(x);
    var ix = u;
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

    var hi = f - hfsq;
    u = @bitCast(hi);
    u &= 0xFFFFF000;
    hi = @bitCast(u);
    const lo = f - hi - hfsq + s * (hfsq + R);
    return (lo + hi) * ivln2lo + lo * ivln2hi + hi * ivln2hi + @as(f32, @floatFromInt(k));
}

pub fn log2(x_: f64) callconv(.C) f64 {
    const ivln2hi: f64 = 1.44269504072144627571e+00;
    const ivln2lo: f64 = 1.67517131648865118353e-10;
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
        hx = @intCast(@as(u64, @bitCast(x)) >> 32);
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

    // hi + lo = f - hfsq + s * (hfsq + R) ~ log(1 + f)
    var hi = f - hfsq;
    var hii = @as(u64, @bitCast(hi));
    hii &= @as(u64, maxInt(u64)) << 32;
    hi = @bitCast(hii);
    const lo = f - hi - hfsq + s * (hfsq + R);

    var val_hi = hi * ivln2hi;
    var val_lo = (lo + hi) * ivln2lo + lo * ivln2hi;

    // spadd(val_hi, val_lo, y)
    const y: f64 = @floatFromInt(k);
    const ww = y + val_hi;
    val_lo += (y - ww) + val_hi;
    val_hi = ww;

    return val_lo + val_hi;
}

pub fn __log2x(a: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(log2q(a));
}

pub fn log2q(a: f128) callconv(.C) f128 {
    // TODO: more correct implementation
    return log2(@floatCast(a));
}

pub fn log2l(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __log2h(x),
        32 => return log2f(x),
        64 => return log2(x),
        80 => return __log2x(x),
        128 => return log2q(x),
        else => @compileError("unreachable"),
    }
}

test "log2_32" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f32, log2f(0.2), -2.321928, epsilon));
    try expect(math.approxEqAbs(f32, log2f(0.8923), -0.164399, epsilon));
    try expect(math.approxEqAbs(f32, log2f(1.5), 0.584962, epsilon));
    try expect(math.approxEqAbs(f32, log2f(37.45), 5.226894, epsilon));
    try expect(math.approxEqAbs(f32, log2f(123123.234375), 16.909744, epsilon));
}

test "log2_64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, log2(0.2), -2.321928, epsilon));
    try expect(math.approxEqAbs(f64, log2(0.8923), -0.164399, epsilon));
    try expect(math.approxEqAbs(f64, log2(1.5), 0.584962, epsilon));
    try expect(math.approxEqAbs(f64, log2(37.45), 5.226894, epsilon));
    try expect(math.approxEqAbs(f64, log2(123123.234375), 16.909744, epsilon));
}

test "log2_32.special" {
    try expect(math.isPositiveInf(log2f(math.inf(f32))));
    try expect(math.isNegativeInf(log2f(0.0)));
    try expect(math.isNan(log2f(-1.0)));
    try expect(math.isNan(log2f(math.nan(f32))));
}

test "log2_64.special" {
    try expect(math.isPositiveInf(log2(math.inf(f64))));
    try expect(math.isNegativeInf(log2(0.0)));
    try expect(math.isNan(log2(-1.0)));
    try expect(math.isNan(log2(math.nan(f64))));
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/log1pf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/log1p.c

const builtin = @import("builtin");
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the natural logarithm of 1 + x with greater accuracy when x is near zero.
///
/// Special Cases:
///  - log1p(+inf)  = +inf
///  - log1p(+-0)   = +-0
///  - log1p(-1)    = -inf
///  - log1p(x)     = nan if x < -1
///  - log1p(nan)   = nan
pub fn log1p(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => log1p_32(x),
        f64 => log1p_64(x),
        else => @compileError("log1p not implemented for " ++ @typeName(T)),
    };
}

fn log1p_32(x: f32) f32 {
    const ln2_hi = 6.9313812256e-01;
    const ln2_lo = 9.0580006145e-06;
    const Lg1: f32 = 0xaaaaaa.0p-24;
    const Lg2: f32 = 0xccce13.0p-25;
    const Lg3: f32 = 0x91e9ee.0p-25;
    const Lg4: f32 = 0xf89e26.0p-26;

    const u = @bitCast(u32, x);
    var ix = u;
    var k: i32 = 1;
    var f: f32 = undefined;
    var c: f32 = undefined;

    // 1 + x < sqrt(2)+
    if (ix < 0x3ED413D0 or ix >> 31 != 0) {
        // x <= -1.0
        if (ix >= 0xBF800000) {
            // log1p(-1) = -inf
            if (x == -1.0) {
                return -math.inf(f32);
            }
            // log1p(x < -1) = nan
            else {
                return math.nan(f32);
            }
        }
        // |x| < 2^(-24)
        if ((ix << 1) < (0x33800000 << 1)) {
            // underflow if subnormal
            if (ix & 0x7F800000 == 0) {
                math.doNotOptimizeAway(x * x);
            }
            return x;
        }
        // sqrt(2) / 2- <= 1 + x < sqrt(2)+
        if (ix <= 0xBE95F619) {
            k = 0;
            c = 0;
            f = x;
        }
    } else if (ix >= 0x7F800000) {
        return x;
    }

    if (k != 0) {
        const uf = 1 + x;
        var iu = @bitCast(u32, uf);
        iu += 0x3F800000 - 0x3F3504F3;
        k = @intCast(i32, iu >> 23) - 0x7F;

        // correction to avoid underflow in c / u
        if (k < 25) {
            c = if (k >= 2) 1 - (uf - x) else x - (uf - 1);
            c /= uf;
        } else {
            c = 0;
        }

        // u into [sqrt(2)/2, sqrt(2)]
        iu = (iu & 0x007FFFFF) + 0x3F3504F3;
        f = @bitCast(f32, iu) - 1;
    }

    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * Lg4);
    const t2 = z * (Lg1 + w * Lg3);
    const R = t2 + t1;
    const hfsq = 0.5 * f * f;
    const dk = @intToFloat(f32, k);

    return s * (hfsq + R) + (dk * ln2_lo + c) - hfsq + f + dk * ln2_hi;
}

fn log1p_64(x: f64) f64 {
    const ln2_hi: f64 = 6.93147180369123816490e-01;
    const ln2_lo: f64 = 1.90821492927058770002e-10;
    const Lg1: f64 = 6.666666666666735130e-01;
    const Lg2: f64 = 3.999999999940941908e-01;
    const Lg3: f64 = 2.857142874366239149e-01;
    const Lg4: f64 = 2.222219843214978396e-01;
    const Lg5: f64 = 1.818357216161805012e-01;
    const Lg6: f64 = 1.531383769920937332e-01;
    const Lg7: f64 = 1.479819860511658591e-01;

    var ix = @bitCast(u64, x);
    var hx = @intCast(u32, ix >> 32);
    var k: i32 = 1;
    var c: f64 = undefined;
    var f: f64 = undefined;

    // 1 + x < sqrt(2)
    if (hx < 0x3FDA827A or hx >> 31 != 0) {
        // x <= -1.0
        if (hx >= 0xBFF00000) {
            // log1p(-1) = -inf
            if (x == -1.0) {
                return -math.inf(f64);
            }
            // log1p(x < -1) = nan
            else {
                return math.nan(f64);
            }
        }
        // |x| < 2^(-53)
        if ((hx << 1) < (0x3CA00000 << 1)) {
            if ((hx & 0x7FF00000) == 0) {
                math.raiseUnderflow();
            }
            return x;
        }
        // sqrt(2) / 2- <= 1 + x < sqrt(2)+
        if (hx <= 0xBFD2BEC4) {
            k = 0;
            c = 0;
            f = x;
        }
    } else if (hx >= 0x7FF00000) {
        return x;
    }

    if (k != 0) {
        const uf = 1 + x;
        const hu = @bitCast(u64, uf);
        var iu = @intCast(u32, hu >> 32);
        iu += 0x3FF00000 - 0x3FE6A09E;
        k = @intCast(i32, iu >> 20) - 0x3FF;

        // correction to avoid underflow in c / u
        if (k < 54) {
            c = if (k >= 2) 1 - (uf - x) else x - (uf - 1);
            c /= uf;
        } else {
            c = 0;
        }

        // u into [sqrt(2)/2, sqrt(2)]
        iu = (iu & 0x000FFFFF) + 0x3FE6A09E;
        const iq = (@as(u64, iu) << 32) | (hu & 0xFFFFFFFF);
        f = @bitCast(f64, iq) - 1;
    }

    const hfsq = 0.5 * f * f;
    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * (Lg4 + w * Lg6));
    const t2 = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7)));
    const R = t2 + t1;
    const dk = @intToFloat(f64, k);

    return s * (hfsq + R) + (dk * ln2_lo + c) - hfsq + f + dk * ln2_hi;
}

test "math.log1p" {
    try expect(log1p(@as(f32, 0.0)) == log1p_32(0.0));
    try expect(log1p(@as(f64, 0.0)) == log1p_64(0.0));
}

test "math.log1p_32" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f32, log1p_32(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f32, log1p_32(0.2), 0.182322, epsilon));
    try expect(math.approxEqAbs(f32, log1p_32(0.8923), 0.637793, epsilon));
    try expect(math.approxEqAbs(f32, log1p_32(1.5), 0.916291, epsilon));
    try expect(math.approxEqAbs(f32, log1p_32(37.45), 3.649359, epsilon));
    try expect(math.approxEqAbs(f32, log1p_32(89.123), 4.501175, epsilon));
    try expect(math.approxEqAbs(f32, log1p_32(123123.234375), 11.720949, epsilon));
}

test "math.log1p_64" {
    const epsilon = 0.000001;

    try expect(math.approxEqAbs(f64, log1p_64(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f64, log1p_64(0.2), 0.182322, epsilon));
    try expect(math.approxEqAbs(f64, log1p_64(0.8923), 0.637793, epsilon));
    try expect(math.approxEqAbs(f64, log1p_64(1.5), 0.916291, epsilon));
    try expect(math.approxEqAbs(f64, log1p_64(37.45), 3.649359, epsilon));
    try expect(math.approxEqAbs(f64, log1p_64(89.123), 4.501175, epsilon));
    try expect(math.approxEqAbs(f64, log1p_64(123123.234375), 11.720949, epsilon));
}

test "math.log1p_32.special" {
    try expect(math.isPositiveInf(log1p_32(math.inf(f32))));
    try expect(log1p_32(0.0) == 0.0);
    try expect(log1p_32(-0.0) == -0.0);
    try expect(math.isNegativeInf(log1p_32(-1.0)));
    try expect(math.isNan(log1p_32(-2.0)));
    try expect(math.isNan(log1p_32(math.nan(f32))));
}

test "math.log1p_64.special" {
    try expect(math.isPositiveInf(log1p_64(math.inf(f64))));
    try expect(log1p_64(0.0) == 0.0);
    try expect(log1p_64(-0.0) == -0.0);
    try expect(math.isNegativeInf(log1p_64(-1.0)));
    try expect(math.isNan(log1p_64(-2.0)));
    try expect(math.isNan(log1p_64(math.nan(f64))));
}

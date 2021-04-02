// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/log2f.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/log2.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns the base-2 logarithm of x.
///
/// Special Cases:
///  - log2(+inf)  = +inf
///  - log2(0)     = -inf
///  - log2(x)     = nan if x < 0
///  - log2(nan)   = nan
pub fn log2(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .ComptimeFloat => {
            return @as(comptime_float, log2_64(x));
        },
        .Float => {
            return switch (T) {
                f32 => log2_32(x),
                f64 => log2_64(x),
                else => @compileError("log2 not implemented for " ++ @typeName(T)),
            };
        },
        .ComptimeInt => comptime {
            var result = 0;
            var x_shifted = x;
            while (b: {
                x_shifted >>= 1;
                break :b x_shifted != 0;
            }) : (result += 1) {}
            return result;
        },
        .Int => |IntType| switch (IntType.signedness) {
            .signed => return @compileError("log2 not implemented for signed integers"),
            .unsigned => return math.log2_int(T, x),
        },
        else => @compileError("log2 not implemented for " ++ @typeName(T)),
    }
}

pub fn log2_32(x_: f32) f32 {
    const ivln2hi: f32 = 1.4428710938e+00;
    const ivln2lo: f32 = -1.7605285393e-04;
    const Lg1: f32 = 0xaaaaaa.0p-24;
    const Lg2: f32 = 0xccce13.0p-25;
    const Lg3: f32 = 0x91e9ee.0p-25;
    const Lg4: f32 = 0xf89e26.0p-26;

    var x = x_;
    var u = @bitCast(u32, x);
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
        ix = @bitCast(u32, x);
    } else if (ix >= 0x7F800000) {
        return x;
    } else if (ix == 0x3F800000) {
        return 0;
    }

    // x into [sqrt(2) / 2, sqrt(2)]
    ix += 0x3F800000 - 0x3F3504F3;
    k += @intCast(i32, ix >> 23) - 0x7F;
    ix = (ix & 0x007FFFFF) + 0x3F3504F3;
    x = @bitCast(f32, ix);

    const f = x - 1.0;
    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * Lg4);
    const t2 = z * (Lg1 + w * Lg3);
    const R = t2 + t1;
    const hfsq = 0.5 * f * f;

    var hi = f - hfsq;
    u = @bitCast(u32, hi);
    u &= 0xFFFFF000;
    hi = @bitCast(f32, u);
    const lo = f - hi - hfsq + s * (hfsq + R);
    return (lo + hi) * ivln2lo + lo * ivln2hi + hi * ivln2hi + @intToFloat(f32, k);
}

pub fn log2_64(x_: f64) f64 {
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
    var ix = @bitCast(u64, x);
    var hx = @intCast(u32, ix >> 32);
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
        hx = @intCast(u32, @bitCast(u64, x) >> 32);
    } else if (hx >= 0x7FF00000) {
        return x;
    } else if (hx == 0x3FF00000 and ix << 32 == 0) {
        return 0;
    }

    // x into [sqrt(2) / 2, sqrt(2)]
    hx += 0x3FF00000 - 0x3FE6A09E;
    k += @intCast(i32, hx >> 20) - 0x3FF;
    hx = (hx & 0x000FFFFF) + 0x3FE6A09E;
    ix = (@as(u64, hx) << 32) | (ix & 0xFFFFFFFF);
    x = @bitCast(f64, ix);

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
    var hii = @bitCast(u64, hi);
    hii &= @as(u64, maxInt(u64)) << 32;
    hi = @bitCast(f64, hii);
    const lo = f - hi - hfsq + s * (hfsq + R);

    var val_hi = hi * ivln2hi;
    var val_lo = (lo + hi) * ivln2lo + lo * ivln2hi;

    // spadd(val_hi, val_lo, y)
    const y = @intToFloat(f64, k);
    const ww = y + val_hi;
    val_lo += (y - ww) + val_hi;
    val_hi = ww;

    return val_lo + val_hi;
}

test "math.log2" {
    expect(log2(@as(f32, 0.2)) == log2_32(0.2));
    expect(log2(@as(f64, 0.2)) == log2_64(0.2));
}

test "math.log2_32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, log2_32(0.2), -2.321928, epsilon));
    expect(math.approxEqAbs(f32, log2_32(0.8923), -0.164399, epsilon));
    expect(math.approxEqAbs(f32, log2_32(1.5), 0.584962, epsilon));
    expect(math.approxEqAbs(f32, log2_32(37.45), 5.226894, epsilon));
    expect(math.approxEqAbs(f32, log2_32(123123.234375), 16.909744, epsilon));
}

test "math.log2_64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, log2_64(0.2), -2.321928, epsilon));
    expect(math.approxEqAbs(f64, log2_64(0.8923), -0.164399, epsilon));
    expect(math.approxEqAbs(f64, log2_64(1.5), 0.584962, epsilon));
    expect(math.approxEqAbs(f64, log2_64(37.45), 5.226894, epsilon));
    expect(math.approxEqAbs(f64, log2_64(123123.234375), 16.909744, epsilon));
}

test "math.log2_32.special" {
    expect(math.isPositiveInf(log2_32(math.inf(f32))));
    expect(math.isNegativeInf(log2_32(0.0)));
    expect(math.isNan(log2_32(-1.0)));
    expect(math.isNan(log2_32(math.nan(f32))));
}

test "math.log2_64.special" {
    expect(math.isPositiveInf(log2_64(math.inf(f64))));
    expect(math.isNegativeInf(log2_64(0.0)));
    expect(math.isNan(log2_64(-1.0)));
    expect(math.isNan(log2_64(math.nan(f64))));
}

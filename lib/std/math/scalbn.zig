// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/scalbnf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/scalbn.c

const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const expect = std.testing.expect;

/// Returns x * 2^n.
pub fn scalbn(x: anytype, n: i32) @TypeOf(x) {
    var base = x;
    var shift = n;

    const T = @TypeOf(base);
    const IntT = std.meta.Int(.unsigned, @bitSizeOf(T));
    if (@typeInfo(T) != .Float) {
        @compileError("scalbn not implemented for " ++ @typeName(T));
    }

    const mantissa_bits = math.floatMantissaBits(T);
    const exponent_bits = math.floatExponentBits(T);
    const exponent_bias = (1 << (exponent_bits - 1)) - 1;
    const exponent_min = 1 - exponent_bias;
    const exponent_max = exponent_bias;

    // fix double rounding errors in subnormal ranges
    // https://git.musl-libc.org/cgit/musl/commit/src/math/scalbn.c?id=8c44a060243f04283ca68dad199aab90336141db
    const scale_min_expo = exponent_min + mantissa_bits + 1;
    const scale_min = @bitCast(T, @as(IntT, scale_min_expo + exponent_bias) << mantissa_bits);
    const scale_max = @bitCast(T, @intCast(IntT, exponent_max + exponent_bias) << mantissa_bits);

    // scale `shift` within floating point limits, if possible
    // second pass is possible due to subnormal range
    // third pass always results in +/-0.0 or +/-inf
    if (shift > exponent_max) {
        base *= scale_max;
        shift -= exponent_max;
        if (shift > exponent_max) {
            base *= scale_max;
            shift -= exponent_max;
            if (shift > exponent_max) shift = exponent_max;
        }
    } else if (shift < exponent_min) {
        base *= scale_min;
        shift -= scale_min_expo;
        if (shift < exponent_min) {
            base *= scale_min;
            shift -= scale_min_expo;
            if (shift < exponent_min) shift = exponent_min;
        }
    }

    return base * @bitCast(T, @intCast(IntT, shift + exponent_bias) << mantissa_bits);
}

test "math.scalbn" {
    // basic usage
    try expect(scalbn(@as(f16, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f32, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f64, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f128, 1.5), 4) == 24.0);

    // subnormals
    try expect(math.isNormal(scalbn(@as(f16, 1.0), -14)));
    try expect(!math.isNormal(scalbn(@as(f16, 1.0), -15)));
    try expect(math.isNormal(scalbn(@as(f32, 1.0), -126)));
    try expect(!math.isNormal(scalbn(@as(f32, 1.0), -127)));
    try expect(math.isNormal(scalbn(@as(f64, 1.0), -1022)));
    try expect(!math.isNormal(scalbn(@as(f64, 1.0), -1023)));
    try expect(math.isNormal(scalbn(@as(f128, 1.0), -16382)));
    try expect(!math.isNormal(scalbn(@as(f128, 1.0), -16383)));
    // unreliable due to lack of native f16 support, see talk on PR #8733
    // try expect(scalbn(@as(f16, 0x1.1FFp-1), -14 - 9) == math.f16_true_min);
    try expect(scalbn(@as(f32, 0x1.3FFFFFp-1), -126 - 22) == math.f32_true_min);
    try expect(scalbn(@as(f64, 0x1.7FFFFFFFFFFFFp-1), -1022 - 51) == math.f64_true_min);
    try expect(scalbn(@as(f128, 0x1.7FFFFFFFFFFFFFFFFFFFFFFFFFFFp-1), -16382 - 111) == math.f128_true_min);

    // float limits
    try expect(scalbn(@as(f32, math.f32_max), -128 - 149) > 0.0);
    try expect(scalbn(@as(f32, math.f32_max), -128 - 149 - 1) == 0.0);
    try expect(!math.isPositiveInf(scalbn(@as(f16, math.f16_true_min), 15 + 24)));
    try expect(math.isPositiveInf(scalbn(@as(f16, math.f16_true_min), 15 + 24 + 1)));
    try expect(!math.isPositiveInf(scalbn(@as(f32, math.f32_true_min), 127 + 149)));
    try expect(math.isPositiveInf(scalbn(@as(f32, math.f32_true_min), 127 + 149 + 1)));
    try expect(!math.isPositiveInf(scalbn(@as(f64, math.f64_true_min), 1023 + 1074)));
    try expect(math.isPositiveInf(scalbn(@as(f64, math.f64_true_min), 1023 + 1074 + 1)));
    try expect(!math.isPositiveInf(scalbn(@as(f128, math.f128_true_min), 16383 + 16494)));
    try expect(math.isPositiveInf(scalbn(@as(f128, math.f128_true_min), 16383 + 16494 + 1)));
}

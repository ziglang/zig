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
    var x_ = x;
    var n_ = n;

    const T = @TypeOf(x_);
    if (@typeInfo(T) != .Float) {
        @compileError("scalbn not implemented for " ++ @typeName(T));
    }

    // calculate float limits
    const TBits = std.meta.Int(.unsigned, @bitSizeOf(T));
    const mantissa_size = @ctz(TBits, @bitCast(TBits, @as(T, 1.0)));
    const exponent_max = @intCast(@TypeOf(n_), @bitCast(TBits, @as(T, 1.0)) >> mantissa_size);
    const exponent_min = (-exponent_max) + 1; // +1 as lowest is reserved for subnormals

    // scale `n_` within floating point limits, if possible
    // second pass is possible due to subnormal range
    // third pass always results in +/-0.0 or +/-inf
    const scale_max = @bitCast(T, @intCast(TBits, exponent_max * 2) << mantissa_size);
    const scale_min = @bitCast(T, @as(TBits, 0b1) << mantissa_size);
    if (n_ > exponent_max) {
        x_ *= scale_max;
        n_ -= exponent_max;
        if (n_ > exponent_max) {
            x_ *= scale_max;
            n_ -= exponent_max;
            if (n_ > exponent_max) n_ = exponent_max;
        }
    } else if (n_ < exponent_min) {
        x_ *= scale_min;
        n_ -= exponent_min;
        if (n_ < exponent_min) {
            x_ *= scale_min;
            n_ -= exponent_min;
            if (n_ < exponent_min) n_ = exponent_min;
        }
    }

    return x_ * @bitCast(T, @intCast(TBits, n_ + exponent_max) << mantissa_size);
}

test "math.scalbn" {
    // basic usage
    try expect(scalbn(@as(f16, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f32, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f64, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f128, 1.5), 4) == 24.0);
    try expect(scalbn(@as(c_longdouble, 1.5), 4) == 24.0);

    // subnormals
    try expect(math.isNormal(scalbn(@as(f32, 1.0), -126)));
    try expect(!math.isNormal(scalbn(@as(f32, 1.0), -127)));

    // float limits
    try expect(scalbn(@as(f32, math.f32_max), -128 - 149) > 0.0);
    try expect(scalbn(@as(f32, math.f32_max), -128 - 149 - 1) == 0.0);
    try expect(!math.isPositiveInf(scalbn(@as(f32, math.f32_true_min), 127 + 149)));
    try expect(math.isPositiveInf(scalbn(@as(f32, math.f32_true_min), 127 + 149 + 1)));
}

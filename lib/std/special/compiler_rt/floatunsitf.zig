// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");

pub fn __floatunsitf(a: u32) callconv(.C) f128 {
    @setRuntimeSafety(is_test);

    if (a == 0) {
        return 0;
    }

    const mantissa_bits = std.math.floatMantissaBits(f128);
    const exponent_bits = std.math.floatExponentBits(f128);
    const exponent_bias = (1 << (exponent_bits - 1)) - 1;
    const implicit_bit = 1 << mantissa_bits;

    const exp = (32 - 1) - @clz(u32, a);
    const shift = mantissa_bits - @intCast(u7, exp);

    // TODO(#1148): @bitCast alignment error
    var result align(16) = (@intCast(u128, a) << shift) ^ implicit_bit;
    result += (@intCast(u128, exp) + exponent_bias) << mantissa_bits;

    return @bitCast(f128, result);
}

test "import floatunsitf" {
    _ = @import("floatunsitf_test.zig");
}

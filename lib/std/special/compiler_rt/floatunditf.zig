// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");

pub fn __floatunditf(a: u64) callconv(.C) f128 {
    @setRuntimeSafety(is_test);

    if (a == 0) {
        return 0;
    }

    const mantissa_bits = std.math.floatMantissaBits(f128);
    const exponent_bits = std.math.floatExponentBits(f128);
    const exponent_bias = (1 << (exponent_bits - 1)) - 1;
    const implicit_bit = 1 << mantissa_bits;

    const exp: u128 = (64 - 1) - @clz(u64, a);
    const shift: u7 = mantissa_bits - @intCast(u7, exp);

    var result: u128 = (@intCast(u128, a) << shift) ^ implicit_bit;
    result += (exp + exponent_bias) << mantissa_bits;

    return @bitCast(f128, result);
}

test "import floatunditf" {
    _ = @import("floatunditf_test.zig");
}

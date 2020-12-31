// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");
const maxInt = std.math.maxInt;

const significandBits = 112;
const exponentBias = 16383;
const implicitBit = (@as(u128, 1) << significandBits);

pub fn __floatditf(arg: i64) callconv(.C) f128 {
    @setRuntimeSafety(is_test);

    if (arg == 0)
        return 0.0;

    // All other cases begin by extracting the sign and absolute value of a
    var sign: u128 = 0;
    var aAbs = @bitCast(u64, arg);
    if (arg < 0) {
        sign = 1 << 127;
        aAbs = ~@bitCast(u64, arg) + 1;
    }

    // Exponent of (fp_t)a is the width of abs(a).
    const exponent = 63 - @clz(u64, aAbs);
    var result: u128 = undefined;

    // Shift a into the significand field, rounding if it is a right-shift
    const shift = significandBits - exponent;
    result = @as(u128, aAbs) << shift ^ implicitBit;

    result += (@as(u128, exponent) + exponentBias) << significandBits;
    return @bitCast(f128, result | sign);
}

test "import floatditf" {
    _ = @import("floatditf_test.zig");
}

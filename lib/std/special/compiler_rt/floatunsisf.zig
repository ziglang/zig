// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std");
const maxInt = std.math.maxInt;

const significandBits = 23;
const exponentBias = 127;
const implicitBit = @as(u32, 1) << significandBits;

pub fn __floatunsisf(arg: u32) callconv(.C) f32 {
    @setRuntimeSafety(builtin.is_test);

    if (arg == 0) return 0.0;

    // The exponent is the width of abs(a)
    const exp = @as(u32, 31) - @clz(u32, arg);

    var mantissa: u32 = undefined;
    if (exp <= significandBits) {
        // Shift a into the significand field and clear the implicit bit
        const shift = @intCast(u5, significandBits - exp);
        mantissa = @as(u32, arg) << shift ^ implicitBit;
    } else {
        const shift = @intCast(u5, exp - significandBits);
        // Round to the nearest number after truncation
        mantissa = @as(u32, arg) >> shift ^ implicitBit;
        // Align to the left and check if the truncated part is halfway over
        const round = arg << @intCast(u5, 31 - shift);
        mantissa += @boolToInt(round > 0x80000000);
        // Tie to even
        mantissa += mantissa & 1;
    }

    // Use the addition instead of a or since we may have a carry from the
    // mantissa to the exponent
    var result = mantissa;
    result += (exp + exponentBias) << significandBits;

    return @bitCast(f32, result);
}

pub fn __aeabi_ui2f(arg: u32) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __floatunsisf, .{arg});
}

fn test_one_floatunsisf(a: u32, expected: u32) void {
    const r = __floatunsisf(a);
    std.testing.expect(@bitCast(u32, r) == expected);
}

test "floatunsisf" {
    // Test the produced bit pattern
    test_one_floatunsisf(0, 0);
    test_one_floatunsisf(1, 0x3f800000);
    test_one_floatunsisf(0x7FFFFFFF, 0x4f000000);
    test_one_floatunsisf(0x80000000, 0x4f000000);
    test_one_floatunsisf(0xFFFFFFFF, 0x4f800000);
}

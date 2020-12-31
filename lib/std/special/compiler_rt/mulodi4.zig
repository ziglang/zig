// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

pub fn __mulodi4(a: i64, b: i64, overflow: *c_int) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);

    const min = @bitCast(i64, @as(u64, 1 << (64 - 1)));
    const max = ~min;

    overflow.* = 0;
    const result = a *% b;

    // Edge cases
    if (a == min) {
        if (b != 0 and b != 1) overflow.* = 1;
        return result;
    }
    if (b == min) {
        if (a != 0 and a != 1) overflow.* = 1;
        return result;
    }

    // Take absolute value of a and b via abs(x) = (x^(x >> 63)) - (x >> 63).
    const abs_a = (a ^ (a >> 63)) -% (a >> 63);
    const abs_b = (b ^ (b >> 63)) -% (b >> 63);

    // Unitary magnitude, cannot have overflow
    if (abs_a < 2 or abs_b < 2) return result;

    // Compare the signs of the operands
    if ((a ^ b) >> 63 != 0) {
        if (abs_a > @divTrunc(max, abs_b)) overflow.* = 1;
    } else {
        if (abs_a > @divTrunc(min, -abs_b)) overflow.* = 1;
    }

    return result;
}

test "import mulodi4" {
    _ = @import("mulodi4_test.zig");
}

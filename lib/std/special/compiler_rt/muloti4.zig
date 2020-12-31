// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

pub fn __muloti4(a: i128, b: i128, overflow: *c_int) callconv(.C) i128 {
    @setRuntimeSafety(builtin.is_test);

    const min = @bitCast(i128, @as(u128, 1 << (128 - 1)));
    const max = ~min;
    overflow.* = 0;

    const r = a *% b;
    if (a == min) {
        if (b != 0 and b != 1) {
            overflow.* = 1;
        }
        return r;
    }
    if (b == min) {
        if (a != 0 and a != 1) {
            overflow.* = 1;
        }
        return r;
    }

    const sa = a >> (128 - 1);
    const abs_a = (a ^ sa) -% sa;
    const sb = b >> (128 - 1);
    const abs_b = (b ^ sb) -% sb;

    if (abs_a < 2 or abs_b < 2) {
        return r;
    }

    if (sa == sb) {
        if (abs_a > @divTrunc(max, abs_b)) {
            overflow.* = 1;
        }
    } else {
        if (abs_a > @divTrunc(min, -abs_b)) {
            overflow.* = 1;
        }
    }

    return r;
}

test "import muloti4" {
    _ = @import("muloti4_test.zig");
}

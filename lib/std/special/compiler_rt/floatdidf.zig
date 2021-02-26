// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std");

const twop52: f64 = 0x1.0p52;
const twop32: f64 = 0x1.0p32;

pub fn __floatdidf(a: i64) callconv(.C) f64 {
    @setRuntimeSafety(builtin.is_test);

    if (a == 0) return 0;

    var low = @bitCast(i64, twop52);
    const high = @intToFloat(f64, @truncate(i32, a >> 32)) * twop32;

    low |= @bitCast(i64, a & 0xFFFFFFFF);

    return (high - twop52) + @bitCast(f64, low);
}

pub fn __aeabi_l2d(arg: i64) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __floatdidf, .{arg});
}

test "import floatdidf" {
    _ = @import("floatdidf_test.zig");
}

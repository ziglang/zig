// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std");

const twop52: f64 = 0x1.0p52;
const twop84: f64 = 0x1.0p84;
const twop84_plus_twop52: f64 = 0x1.00000001p84;

pub fn __floatundidf(a: u64) callconv(.C) f64 {
    @setRuntimeSafety(builtin.is_test);

    if (a == 0) return 0;

    var high = @bitCast(u64, twop84);
    var low = @bitCast(u64, twop52);

    high |= a >> 32;
    low |= a & 0xFFFFFFFF;

    return (@bitCast(f64, high) - twop84_plus_twop52) + @bitCast(f64, low);
}

pub fn __aeabi_ul2d(arg: u64) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __floatundidf, .{arg});
}

test "import floatundidf" {
    _ = @import("floatundidf_test.zig");
}

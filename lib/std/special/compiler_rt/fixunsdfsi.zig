// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunsdfsi(a: f64) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f64, u32, a);
}

pub fn __aeabi_d2uiz(arg: f64) callconv(.AAPCS) u32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixunsdfsi, .{arg});
}

test "import fixunsdfsi" {
    _ = @import("fixunsdfsi_test.zig");
}

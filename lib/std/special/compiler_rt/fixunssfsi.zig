// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunssfsi(a: f32) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f32, u32, a);
}

pub fn __aeabi_f2uiz(a: f32) callconv(.AAPCS) u32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixunssfsi, .{a});
}

test "import fixunssfsi" {
    _ = @import("fixunssfsi_test.zig");
}

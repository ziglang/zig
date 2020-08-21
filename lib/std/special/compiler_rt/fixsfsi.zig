// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixsfsi(a: f32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f32, i32, a);
}

pub fn __aeabi_f2iz(a: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixsfsi, .{a});
}

test "import fixsfsi" {
    _ = @import("fixsfsi_test.zig");
}

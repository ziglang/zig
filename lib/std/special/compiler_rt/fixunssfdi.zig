// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunssfdi(a: f32) callconv(.C) u64 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f32, u64, a);
}

pub fn __aeabi_f2ulz(a: f32) callconv(.AAPCS) u64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixunssfdi, .{a});
}

test "import fixunssfdi" {
    _ = @import("fixunssfdi_test.zig");
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixdfdi(a: f64) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f64, i64, a);
}

pub fn __aeabi_d2lz(arg: f64) callconv(.AAPCS) i64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __fixdfdi, .{arg});
}

test "import fixdfdi" {
    _ = @import("fixdfdi_test.zig");
}

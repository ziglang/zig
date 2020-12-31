// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunstfdi(a: f128) callconv(.C) u64 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f128, u64, a);
}

test "import fixunstfdi" {
    _ = @import("fixunstfdi_test.zig");
}

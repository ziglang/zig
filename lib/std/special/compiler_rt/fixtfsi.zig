// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixtfsi(a: f128) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i32, a);
}

test "import fixtfsi" {
    _ = @import("fixtfsi_test.zig");
}

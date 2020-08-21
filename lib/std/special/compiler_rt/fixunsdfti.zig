// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixuint = @import("fixuint.zig").fixuint;
const builtin = @import("builtin");

pub fn __fixunsdfti(a: f64) callconv(.C) u128 {
    @setRuntimeSafety(builtin.is_test);
    return fixuint(f64, u128, a);
}

test "import fixunsdfti" {
    _ = @import("fixunsdfti_test.zig");
}

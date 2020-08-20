// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixdfti(a: f64) callconv(.C) i128 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f64, i128, a);
}

test "import fixdfti" {
    _ = @import("fixdfti_test.zig");
}

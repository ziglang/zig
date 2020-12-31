// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixtfti(a: f128) callconv(.C) i128 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i128, a);
}

test "import fixtfti" {
    _ = @import("fixtfti_test.zig");
}

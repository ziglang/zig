// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const fixint = @import("fixint.zig").fixint;
const builtin = @import("builtin");

pub fn __fixtfdi(a: f128) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);
    return fixint(f128, i64, a);
}

test "import fixtfdi" {
    _ = @import("fixtfdi_test.zig");
}

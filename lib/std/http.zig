// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
test "std.http" {
    _ = @import("http/headers.zig");
}

pub const Headers = @import("http/headers.zig").Headers;

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");

pub const deflate = @import("compress/deflate.zig");
pub const zlib = @import("compress/zlib.zig");

test "" {
    _ = zlib;
}

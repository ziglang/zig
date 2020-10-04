// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// Deprecated: use `std.io.counting_writer.CountingWriter`
pub const CountingOutStream = @import("./counting_writer.zig").CountingWriter;

/// Deprecated: use `std.io.counting_writer.countingWriter`
pub const countingOutStream = @import("./counting_writer.zig").countingWriter;

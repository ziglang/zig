// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// Deprecated: use `std.io.buffered_writer.BufferedWriter`
pub const BufferedOutStream = @import("./buffered_writer.zig").BufferedWriter;

/// Deprecated: use `std.io.buffered_writer.bufferedWriter`
pub const bufferedOutStream = @import("./buffered_writer.zig").bufferedWriter;

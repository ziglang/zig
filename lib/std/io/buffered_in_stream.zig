// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// Deprecated: use `std.io.buffered_reader.BufferedReader`
pub const BufferedInStream = @import("./buffered_reader.zig").BufferedReader;

/// Deprecated: use `std.io.buffered_reader.bufferedReader`
pub const bufferedInStream = @import("./buffered_reader.zig").bufferedReader;

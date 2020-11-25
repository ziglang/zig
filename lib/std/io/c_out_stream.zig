// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// Deprecated: use `std.io.c_writer.CWriter`
pub const COutStream = @import("./c_writer.zig").CWriter;

/// Deprecated: use `std.io.c_writer.cWriter`
pub const cOutStream = @import("./c_writer.zig").cWriter;

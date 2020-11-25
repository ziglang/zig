// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// Deprecated: use `std.io.bit_reader.BitReader`
pub const BitInStream = @import("./bit_reader.zig").BitReader;

/// Deprecated: use `std.io.bit_reader.bitReader`
pub const bitInStream = @import("./bit_reader.zig").bitReader;

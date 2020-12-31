// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub const TableHeader = extern struct {
    signature: u64,
    revision: u32,

    /// The size, in bytes, of the entire table including the TableHeader
    header_size: u32,
    crc32: u32,
    reserved: u32,
};

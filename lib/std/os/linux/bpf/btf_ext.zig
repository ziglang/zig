// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub const Header = packed struct {
    magic: u16,
    version: u8,
    flags: u8,
    hdr_len: u32,

    /// All offsets are in bytes relative to the end of this header
    func_info_off: u32,
    func_info_len: u32,
    line_info_off: u32,
    line_info_len: u32,
};

pub const InfoSec = packed struct {
    sec_name_off: u32,
    num_info: u32,
    // TODO: communicate that there is data here
    //data: [0]u8,
};

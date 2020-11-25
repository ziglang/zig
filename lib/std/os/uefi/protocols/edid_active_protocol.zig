// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;

/// EDID information for an active video output device
pub const EdidActiveProtocol = extern struct {
    size_of_edid: u32,
    edid: ?[*]u8,

    pub const guid align(8) = Guid{
        .time_low = 0xbd8c1056,
        .time_mid = 0x9f36,
        .time_high_and_version = 0x44ec,
        .clock_seq_high_and_reserved = 0x92,
        .clock_seq_low = 0xa8,
        .node = [_]u8{ 0xa6, 0x33, 0x7f, 0x81, 0x79, 0x86 },
    };
};

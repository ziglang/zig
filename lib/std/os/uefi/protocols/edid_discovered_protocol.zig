// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;

/// EDID information for a video output device
pub const EdidDiscoveredProtocol = extern struct {
    size_of_edid: u32,
    edid: ?[*]u8,

    pub const guid align(8) = Guid{
        .time_low = 0x1c0c34f6,
        .time_mid = 0xd380,
        .time_high_and_version = 0x41fa,
        .clock_seq_high_and_reserved = 0xa0,
        .clock_seq_low = 0x49,
        .node = [_]u8{ 0x8a, 0xd0, 0x6c, 0x1a, 0x66, 0xaa },
    };
};

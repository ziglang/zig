// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const InputKey = uefi.protocols.InputKey;
const Status = uefi.Status;

/// Character input devices, e.g. Keyboard
pub const SimpleTextInputProtocol = extern struct {
    _reset: fn (*const SimpleTextInputProtocol, bool) callconv(.C) Status,
    _read_key_stroke: fn (*const SimpleTextInputProtocol, *InputKey) callconv(.C) Status,
    wait_for_key: Event,

    /// Resets the input device hardware.
    pub fn reset(self: *const SimpleTextInputProtocol, verify: bool) Status {
        return self._reset(self, verify);
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStroke(self: *const SimpleTextInputProtocol, input_key: *InputKey) Status {
        return self._read_key_stroke(self, input_key);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x387477c1,
        .time_mid = 0x69c7,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
};

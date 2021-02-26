// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;

/// Protocol for mice
pub const SimplePointerProtocol = struct {
    _reset: fn (*const SimplePointerProtocol, bool) callconv(.C) Status,
    _get_state: fn (*const SimplePointerProtocol, *SimplePointerState) callconv(.C) Status,
    wait_for_input: Event,
    mode: *SimplePointerMode,

    /// Resets the pointer device hardware.
    pub fn reset(self: *const SimplePointerProtocol, verify: bool) Status {
        return self._reset(self, verify);
    }

    /// Retrieves the current state of a pointer device.
    pub fn getState(self: *const SimplePointerProtocol, state: *SimplePointerState) Status {
        return self._get_state(self, state);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x31878c87,
        .time_mid = 0x0b75,
        .time_high_and_version = 0x11d5,
        .clock_seq_high_and_reserved = 0x9a,
        .clock_seq_low = 0x4f,
        .node = [_]u8{ 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
    };
};

pub const SimplePointerMode = struct {
    resolution_x: u64,
    resolution_y: u64,
    resolution_z: u64,
    left_button: bool,
    right_button: bool,
};

pub const SimplePointerState = struct {
    relative_movement_x: i32 = undefined,
    relative_movement_y: i32 = undefined,
    relative_movement_z: i32 = undefined,
    left_button: bool = undefined,
    right_button: bool = undefined,
};

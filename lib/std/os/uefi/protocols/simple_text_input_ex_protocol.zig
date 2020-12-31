// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;

/// Character input devices, e.g. Keyboard
pub const SimpleTextInputExProtocol = extern struct {
    _reset: fn (*const SimpleTextInputExProtocol, bool) callconv(.C) Status,
    _read_key_stroke_ex: fn (*const SimpleTextInputExProtocol, *KeyData) callconv(.C) Status,
    wait_for_key_ex: Event,
    _set_state: fn (*const SimpleTextInputExProtocol, *const u8) callconv(.C) Status,
    _register_key_notify: fn (*const SimpleTextInputExProtocol, *const KeyData, fn (*const KeyData) callconv(.C) usize, **c_void) callconv(.C) Status,
    _unregister_key_notify: fn (*const SimpleTextInputExProtocol, *const c_void) callconv(.C) Status,

    /// Resets the input device hardware.
    pub fn reset(self: *const SimpleTextInputExProtocol, verify: bool) Status {
        return self._reset(self, verify);
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStrokeEx(self: *const SimpleTextInputExProtocol, key_data: *KeyData) Status {
        return self._read_key_stroke_ex(self, key_data);
    }

    /// Set certain state for the input device.
    pub fn setState(self: *const SimpleTextInputExProtocol, state: *const u8) Status {
        return self._set_state(self, state);
    }

    /// Register a notification function for a particular keystroke for the input device.
    pub fn registerKeyNotify(self: *const SimpleTextInputExProtocol, key_data: *const KeyData, notify: fn (*const KeyData) callconv(.C) usize, handle: **c_void) Status {
        return self._register_key_notify(self, key_data, notify, handle);
    }

    /// Remove the notification that was previously registered.
    pub fn unregisterKeyNotify(self: *const SimpleTextInputExProtocol, handle: *const c_void) Status {
        return self._unregister_key_notify(self, handle);
    }

    pub const guid align(8) = Guid{
        .time_low = 0xdd9e7534,
        .time_mid = 0x7762,
        .time_high_and_version = 0x4698,
        .clock_seq_high_and_reserved = 0x8c,
        .clock_seq_low = 0x14,
        .node = [_]u8{ 0xf5, 0x85, 0x17, 0xa6, 0x25, 0xaa },
    };
};

pub const KeyData = extern struct {
    key: InputKey = undefined,
    key_state: KeyState = undefined,
};

pub const KeyState = extern struct {
    key_shift_state: packed struct {
        right_shift_pressed: bool,
        left_shift_pressed: bool,
        right_control_pressed: bool,
        left_control_pressed: bool,
        right_alt_pressed: bool,
        left_alt_pressed: bool,
        right_logo_pressed: bool,
        left_logo_pressed: bool,
        menu_key_pressed: bool,
        sys_req_pressed: bool,
        _pad1: u21,
        shift_state_valid: bool,
    },
    key_toggle_state: packed struct {
        scroll_lock_active: bool,
        num_lock_active: bool,
        caps_lock_active: bool,
        _pad1: u3,
        key_state_exposed: bool,
        toggle_state_valid: bool,
    },
};

pub const InputKey = extern struct {
    scan_code: u16,
    unicode_char: u16,
};

const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;

/// Character input devices, e.g. Keyboard
pub const SimpleTextInputEx = extern struct {
    _reset: *const fn (*const SimpleTextInputEx, bool) callconv(cc) Status,
    _read_key_stroke_ex: *const fn (*const SimpleTextInputEx, *Key) callconv(cc) Status,
    wait_for_key_ex: Event,
    _set_state: *const fn (*const SimpleTextInputEx, *const u8) callconv(cc) Status,
    _register_key_notify: *const fn (*const SimpleTextInputEx, *const Key, *const fn (*const Key) callconv(cc) usize, **anyopaque) callconv(cc) Status,
    _unregister_key_notify: *const fn (*const SimpleTextInputEx, *const anyopaque) callconv(cc) Status,

    /// Resets the input device hardware.
    pub fn reset(self: *const SimpleTextInputEx, verify: bool) Status {
        return self._reset(self, verify);
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStrokeEx(self: *const SimpleTextInputEx, key_data: *Key) Status {
        return self._read_key_stroke_ex(self, key_data);
    }

    /// Set certain state for the input device.
    pub fn setState(self: *const SimpleTextInputEx, state: *const u8) Status {
        return self._set_state(self, state);
    }

    /// Register a notification function for a particular keystroke for the input device.
    pub fn registerKeyNotify(self: *const SimpleTextInputEx, key_data: *const Key, notify: *const fn (*const Key) callconv(cc) usize, handle: **anyopaque) Status {
        return self._register_key_notify(self, key_data, notify, handle);
    }

    /// Remove the notification that was previously registered.
    pub fn unregisterKeyNotify(self: *const SimpleTextInputEx, handle: *const anyopaque) Status {
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

    pub const Key = extern struct {
        input: Input,
        state: State,

        pub const State = extern struct {
            shift: Shift,
            toggle: Toggle,

            pub const Shift = packed struct(u32) {
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
                _pad: u21 = 0,
                shift_state_valid: bool,
            };

            pub const Toggle = packed struct(u8) {
                scroll_lock_active: bool,
                num_lock_active: bool,
                caps_lock_active: bool,
                _pad: u3 = 0,
                key_state_exposed: bool,
                toggle_state_valid: bool,
            };
        };

        pub const Input = extern struct {
            scan_code: u16,
            unicode_char: u16,
        };
    };
};

const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

/// Character input devices, e.g. Keyboard
pub const SimpleTextInputEx = extern struct {
    _reset: *const fn (*SimpleTextInputEx, bool) callconv(cc) Status,
    _read_key_stroke_ex: *const fn (*SimpleTextInputEx, *Key) callconv(cc) Status,
    wait_for_key_ex: Event,
    _set_state: *const fn (*SimpleTextInputEx, *const u8) callconv(cc) Status,
    _register_key_notify: *const fn (*SimpleTextInputEx, *const Key, *const fn (*const Key) callconv(cc) Status, **anyopaque) callconv(cc) Status,
    _unregister_key_notify: *const fn (*SimpleTextInputEx, *const anyopaque) callconv(cc) Status,

    pub const ResetError = uefi.UnexpectedError || error{DeviceError};
    pub const ReadKeyStrokeError = uefi.UnexpectedError || error{
        NotReady,
        DeviceError,
        Unsupported,
    };
    pub const SetStateError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };
    pub const RegisterKeyNotifyError = uefi.UnexpectedError || error{OutOfResources};
    pub const UnregisterKeyNotifyError = uefi.UnexpectedError || error{InvalidParameter};

    /// Resets the input device hardware.
    pub fn reset(self: *SimpleTextInputEx, verify: bool) ResetError!void {
        switch (self._reset(self, verify)) {
            .success => {},
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStroke(self: *SimpleTextInputEx) ReadKeyStrokeError!Key {
        var key: Key = undefined;
        switch (self._read_key_stroke_ex(self, &key)) {
            .success => return key,
            .not_ready => return Error.NotReady,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Set certain state for the input device.
    pub fn setState(self: *SimpleTextInputEx, state: *const Key.State.Toggle) SetStateError!void {
        switch (self._set_state(self, @ptrCast(state))) {
            .success => {},
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Register a notification function for a particular keystroke for the input device.
    pub fn registerKeyNotify(
        self: *SimpleTextInputEx,
        key_data: *const Key,
        notify: *const fn (*const Key) callconv(cc) Status,
    ) RegisterKeyNotifyError!uefi.Handle {
        var handle: uefi.Handle = undefined;
        switch (self._register_key_notify(self, key_data, notify, &handle)) {
            .success => return handle,
            .out_of_resources => return Error.OutOfResources,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Remove the notification that was previously registered.
    pub fn unregisterKeyNotify(
        self: *SimpleTextInputEx,
        handle: uefi.Handle,
    ) UnregisterKeyNotifyError!void {
        switch (self._unregister_key_notify(self, handle)) {
            .success => {},
            .invalid_parameter => return Error.InvalidParameter,
            else => |status| return uefi.unexpectedStatus(status),
        }
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

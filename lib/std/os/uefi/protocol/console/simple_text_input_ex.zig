const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;
const Event = bits.Event;

/// The Simple Text Input Ex protocol defines an extension to the Simple Text Input protocol
/// which enables various new capabilities.
pub const SimpleTextInputEx = extern struct {
    _reset: *const fn (*const SimpleTextInputEx, verify: bool) callconv(cc) Status,
    _read_key_stroke_ex: *const fn (*const SimpleTextInputEx, key: *Key) callconv(cc) Status,
    wait_for_key_ex: Event,
    _set_state: *const fn (*const SimpleTextInputEx, state: *const Key.State.Toggle) callconv(cc) Status,
    _register_key_notify: *const fn (*const SimpleTextInputEx, key: *Key, func: *const fn (*const Key) callconv(cc) usize, handle: *NotifyHandle) callconv(cc) Status,
    _unregister_key_notify: *const fn (*const SimpleTextInputEx, handle: NotifyHandle) callconv(cc) Status,

    /// Resets the input device hardware.
    pub fn reset(
        self: *const SimpleTextInputEx,
        /// Indicates that the driver may perform a more exhaustive verification operation of the device during reset.
        verify: bool,
    ) !void {
        try self._reset(self, verify).err();
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStrokeEx(self: *const SimpleTextInputEx) !Key {
        var key_data: Key = undefined;
        try self._read_key_stroke_ex(self, &key_data).err();
        return key_data;
    }

    /// Set certain state for the input device.
    pub fn setState(self: *const SimpleTextInputEx, state: Key.State.Toggle) !void {
        try self._set_state(self, &state).err();
    }

    pub const NotifyFn = *const fn (*const Key) callconv(cc) Status;
    pub const NotifyHandle = *const opaque {};

    /// Register a notification function for a particular keystroke for the input device.
    pub fn registerKeyNotify(
        self: *const SimpleTextInputEx,
        /// Buffer that is filled with keystroke information
        key_data: *Key,
        /// Pointer to function to be called for a key press.
        notify: NotifyFn,
    ) !NotifyHandle {
        var handle: NotifyHandle = undefined;
        try self._register_key_notify(self, key_data, notify, &handle).err();
        return handle;
    }

    /// Remove the notification that was previously registered.
    pub fn unregisterKeyNotify(
        self: *const SimpleTextInputEx,
        /// The handle of the notification function being unregistered.
        handle: NotifyHandle,
    ) Status {
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

                /// This bitfield is only valid when this is true.
                shift_state_valid: bool,
            };

            pub const Toggle = packed struct(u8) {
                scroll_lock_active: bool,
                num_lock_active: bool,
                caps_lock_active: bool,
                _pad: u3 = 0,

                /// When true, this instance of the protocol supports partial keystrokes.
                key_state_exposed: bool,

                /// This bitfield is only valid when this is true.
                toggle_state_valid: bool,
            };
        };

        pub const Input = extern struct {
            scan_code: u16,
            unicode_char: u16,
        };
    };
};

const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;
const Event = bits.Event;

/// Provides services that allow information about an absolute pointer device to be retrieved.
pub const AbsolutePointer = extern struct {
    _reset: *const fn (*const AbsolutePointer, verify: bool) callconv(cc) Status,
    _get_state: *const fn (*const AbsolutePointer, state: *State) callconv(cc) Status,

    /// Event to use with `waitForEvent()` to wait for input from the pointer device.
    wait_for_input: Event,

    /// The current mode of the pointer device.
    mode: *Mode,

    pub const Mode = extern struct {
        absolute_min_x: u64,
        absolute_min_y: u64,
        absolute_min_z: u64,

        /// If zero, the device does not support a x-axis.
        absolute_max_x: u64,

        /// If zero, the device does not support a y-axis.
        absolute_max_y: u64,

        /// If zero, the device does not support a z-axis.
        absolute_max_z: u64,

        attributes: Attributes,

        pub const Attributes = packed struct(u32) {
            /// Supports an alternate button input.
            supports_alt_active: bool,

            /// Returns pressure data as the z-axis.
            supports_pressure_as_z: bool,

            _pad: u30 = 0,
        };
    };

    /// Resets the pointer device hardware.
    pub fn reset(
        self: *const AbsolutePointer,
        /// Indicates that the driver may perform a more exhaustive verification operation of the device during reset.
        verify: bool,
    ) !void {
        try self._reset(self, verify).err();
    }

    pub const State = extern struct {
        /// Must be ignored when both `absolute_min_x` and `absolute_max_x` are zero.
        current_x: u64,

        /// Must be ignored when both `absolute_min_y` and `absolute_max_y` are zero.
        current_y: u64,

        /// Must be ignored when both `absolute_min_z` and `absolute_max_z` are zero.
        current_z: u64,
        active_buttons: ActiveButtons,

        pub const ActiveButtons = packed struct(u32) {
            /// The touch sensor is active.
            touch_active: bool,

            /// The alt sensor is active, such as a pen side button.
            alt_active: bool,
            _pad: u30 = 0,
        };
    };

    /// Retrieves the current state of a pointer device.
    pub fn getState(self: *const AbsolutePointer) !State {
        var state: State = undefined;
        try self._get_state(self, &state).err();
        return state;
    }

    pub const guid align(8) = Guid{
        .time_low = 0x8d59d32b,
        .time_mid = 0xc655,
        .time_high_and_version = 0x4ae9,
        .clock_seq_high_and_reserved = 0x9b,
        .clock_seq_low = 0x15,
        .node = [_]u8{ 0xf2, 0x59, 0x04, 0x99, 0x2a, 0x43 },
    };
};

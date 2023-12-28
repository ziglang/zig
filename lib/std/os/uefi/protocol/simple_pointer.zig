const bits = @import("../bits.zig");

const cc = bits.cc;
const Status = @import("../status.zig").Status;

const Guid = bits.Guid;
const Event = bits.Event;

/// Provides services that allow information about a pointer device to be retrieved.
pub const SimplePointer = struct {
    _reset: *const fn (*const SimplePointer, bool) callconv(cc) Status,
    _get_state: *const fn (*const SimplePointer, *State) callconv(cc) Status,

    /// Event to use with `waitForEvent()` to wait for input from the pointer device.
    wait_for_input: Event,

    /// The current mode of the pointer device.
    mode: *Mode,

    pub const Mode = extern struct {
        /// The resolution of the pointer device in counts/mm. If zero, this device does not support an x-axis.
        resolution_x: u64,

        /// The resolution of the pointer device in counts/mm. If zero, this device does not support a y-axis.
        resolution_y: u64,

        /// The resolution of the pointer device in counts/mm. If zero, this device does not support a z-axis.
        resolution_z: u64,

        /// When true, a left button is present on the pointer device.
        left_button: bool,

        /// When true, a right button is present on the pointer device.
        right_button: bool,
    };

    /// Resets the pointer device hardware.
    pub fn reset(
        self: *const SimplePointer,
        /// Indicates that the driver may perform a more exhaustive verification operation of the device during reset.
        verify: bool,
    ) !void {
        try self._reset(self, verify).err();
    }

    pub const State = extern struct {
        /// Relative distance moved in counts. Must be ignored when `mode.resolution_x` is zero.
        relative_movement_x: i32,

        /// Relative distance moved in counts. Must be ignored when `mode.resolution_y` is zero.
        relative_movement_y: i32,

        /// Relative distance moved in counts. Must be ignored when `mode.resolution_z` is zero.
        relative_movement_z: i32,

        /// When true, the left button is pressed. Must be ignored when `mode.left_button` is false.
        left_button: bool,

        /// When true, the right button is pressed. Must be ignored when `mode.right_button` is false.
        right_button: bool,
    };

    /// Retrieves the current state of a pointer device.
    pub fn getState(self: *const SimplePointer) !State {
        var state: State = undefined;
        try self._get_state(self, &state).err();
        return state;
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

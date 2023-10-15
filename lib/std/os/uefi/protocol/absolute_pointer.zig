const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;

/// Protocol for touchscreens.
pub const AbsolutePointer = extern struct {
    _reset: *const fn (*const AbsolutePointer, bool) callconv(cc) Status,
    _get_state: *const fn (*const AbsolutePointer, *State) callconv(cc) Status,
    wait_for_input: Event,
    mode: *Mode,

    /// Resets the pointer device hardware.
    pub fn reset(self: *const AbsolutePointer, verify: bool) Status {
        return self._reset(self, verify);
    }

    /// Retrieves the current state of a pointer device.
    pub fn getState(self: *const AbsolutePointer, state: *State) Status {
        return self._get_state(self, state);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x8d59d32b,
        .time_mid = 0xc655,
        .time_high_and_version = 0x4ae9,
        .clock_seq_high_and_reserved = 0x9b,
        .clock_seq_low = 0x15,
        .node = [_]u8{ 0xf2, 0x59, 0x04, 0x99, 0x2a, 0x43 },
    };

    pub const Mode = extern struct {
        absolute_min_x: u64,
        absolute_min_y: u64,
        absolute_min_z: u64,
        absolute_max_x: u64,
        absolute_max_y: u64,
        absolute_max_z: u64,
        attributes: Attributes,

        pub const Attributes = packed struct(u32) {
            supports_alt_active: bool,
            supports_pressure_as_z: bool,
            _pad: u30 = 0,
        };
    };

    pub const State = extern struct {
        current_x: u64,
        current_y: u64,
        current_z: u64,
        active_buttons: ActiveButtons,

        pub const ActiveButtons = packed struct(u32) {
            touch_active: bool,
            alt_active: bool,
            _pad: u30 = 0,
        };
    };
};

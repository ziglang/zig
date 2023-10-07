const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;

/// Character input devices, e.g. Keyboard
pub const SimpleTextInput = extern struct {
    _reset: *const fn (*const SimpleTextInput, bool) callconv(cc) Status,
    _read_key_stroke: *const fn (*const SimpleTextInput, *Key.Input) callconv(cc) Status,
    wait_for_key: Event,

    /// Resets the input device hardware.
    pub fn reset(self: *const SimpleTextInput, verify: bool) Status {
        return self._reset(self, verify);
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStroke(self: *const SimpleTextInput, input_key: *Key.Input) Status {
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

    pub const Key = uefi.protocol.SimpleTextInputEx.Key;
};

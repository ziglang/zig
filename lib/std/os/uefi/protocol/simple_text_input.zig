const std = @import("std");
const uefi = std.os.uefi;
const Event = uefi.Event;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

/// Character input devices, e.g. Keyboard
pub const SimpleTextInput = extern struct {
    _reset: *const fn (*SimpleTextInput, bool) callconv(cc) Status,
    _read_key_stroke: *const fn (*SimpleTextInput, *Key.Input) callconv(cc) Status,
    wait_for_key: Event,

    pub const ResetError = uefi.UnexpectedError || error{DeviceError};
    pub const ReadKeyStrokeError = uefi.UnexpectedError || error{
        NotReady,
        DeviceError,
        Unsupported,
    };

    /// Resets the input device hardware.
    pub fn reset(self: *SimpleTextInput, verify: bool) ResetError!void {
        switch (self._reset(self, verify)) {
            .success => {},
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStroke(self: *SimpleTextInput) ReadKeyStrokeError!Key.Input {
        var key: Key.Input = undefined;
        switch (self._read_key_stroke(self, &key)) {
            .success => return key,
            .not_ready => return Error.NotReady,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
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

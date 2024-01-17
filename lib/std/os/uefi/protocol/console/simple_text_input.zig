const bits = @import("../../bits.zig");
const protocol = @import("../../protocol.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;
const Event = bits.Event;

/// Character input devices, e.g. Keyboard
pub const SimpleTextInput = extern struct {
    _reset: *const fn (*const SimpleTextInput, verify: bool) callconv(cc) Status,
    _read_key_stroke: *const fn (*const SimpleTextInput, key: *Key.Input) callconv(cc) Status,
    wait_for_key: Event,

    /// Resets the input device hardware.
    pub fn reset(
        self: *const SimpleTextInput,
        /// Indicates that the driver may perform a more exhaustive verification operation of
        /// the device during reset.
        verify: bool,
    ) !void {
        try self._reset(self, verify).err();
    }

    /// Reads the next keystroke from the input device.
    pub fn readKeyStroke(self: *const SimpleTextInput) !?Key.Input {
        var input_key: Key.Input = undefined;
        switch (self._read_key_stroke(self, &input_key)) {
            .success => return input_key,
            .not_ready => return null,
            else => |s| {
                try s.err();
                unreachable;
            },
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

    pub const Key = protocol.SimpleTextInputEx.Key;
};

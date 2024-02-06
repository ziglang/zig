const std = @import("../../../../std.zig");
const bits = @import("../../bits.zig");
const protocol = @import("../../protocol.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;
const DevicePath = protocol.DevicePath;

pub const PathToText = extern struct {
    _convert_device_node_to_text: *const fn (node: *const DevicePath, display_only: bool, allow_shortcuts: bool) callconv(cc) ?[*:0]const u16,
    _convert_device_path_to_text: *const fn (path: *const DevicePath, display_only: bool, allow_shortcuts: bool) callconv(cc) ?[*:0]const u16,

    /// Convert a device node to its text representation.
    pub fn convertNodeToText(
        self: *const PathToText,
        /// Points to the device path to be converted.
        node: *const DevicePath,
        /// If true, the shorter non-parseable text representation is used.
        display_only: bool,
        /// If true, the shortcut forms of text representation are used.
        allow_shortcuts: bool,
    ) ?[:0]const u16 {
        const ptr = self._convert_device_node_to_text(node, display_only, allow_shortcuts) orelse return null;
        return std.mem.span(ptr);
    }

    /// Convert a device path to its text representation.
    pub fn convertPathToText(
        self: *const PathToText,
        /// Points to the device path to be converted.
        path: *const DevicePath,
        /// If true, the shorter non-parseable text representation is used.
        display_only: bool,
        /// If true, the shortcut forms of text representation are used.
        allow_shortcuts: bool,
    ) ?[:0]const u16 {
        const ptr = self._convert_device_path_to_text(path, display_only, allow_shortcuts) orelse return null;
        return std.mem.span(ptr);
    }

    pub const guid align(8) = Guid{
        .time_low = 0x8b843e20,
        .time_mid = 0x8132,
        .time_high_and_version = 0x4852,
        .clock_seq_high_and_reserved = 0x90,
        .clock_seq_low = 0xcc,
        .node = [_]u8{ 0x55, 0x1a, 0x4e, 0x4a, 0x7f, 0x1c },
    };
};

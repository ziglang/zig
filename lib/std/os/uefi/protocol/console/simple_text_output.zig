const std = @import("../../../../std.zig");
const bits = @import("../../bits.zig");

const cc = bits.cc;
const Status = @import("../../status.zig").Status;

const Guid = bits.Guid;
const Event = bits.Event;

/// Character output devices
pub const SimpleTextOutput = extern struct {
    _reset: *const fn (*const SimpleTextOutput, verify: bool) callconv(cc) Status,
    _output_string: *const fn (*const SimpleTextOutput, str: [*:0]const u16) callconv(cc) Status,
    _test_string: *const fn (*const SimpleTextOutput, str: [*:0]const u16) callconv(cc) Status,
    _query_mode: *const fn (*const SimpleTextOutput, mode: usize, cols: *usize, rows: *usize) callconv(cc) Status,
    _set_mode: *const fn (*const SimpleTextOutput, mode: usize) callconv(cc) Status,
    _set_attribute: *const fn (*const SimpleTextOutput, Attribute) callconv(cc) Status,
    _clear_screen: *const fn (*const SimpleTextOutput) callconv(cc) Status,
    _set_cursor_position: *const fn (*const SimpleTextOutput, col: usize, row: usize) callconv(cc) Status,
    _enable_cursor: *const fn (*const SimpleTextOutput, enabled: bool) callconv(cc) Status,

    ///The mode information for this instance of the protocol.
    mode: *Mode,

    // the numbers here are specified as "int32", which implies signed, but signed values make no sense here.
    pub const Mode = extern struct {
        /// The number of modes supported by `queryMode()` and `setMode()`.
        max_mode: u32,

        /// The current mode.
        mode: u32,
        attribute: Attribute,
        cursor_column: u32,
        cursor_row: u32,
        cursor_visible: bool,
    };

    /// Resets the text output device hardware.
    pub fn reset(
        self: *const SimpleTextOutput,
        /// Indicates that the driver may perform a more exhaustive verification operation of
        /// the device during reset.
        verify: bool,
    ) !void {
        try self._reset(self, verify).err();
    }

    /// Writes a string to the output device.
    pub fn outputString(
        self: *const SimpleTextOutput,
        /// The Null-terminated string to be displayed on the output device(s).
        msg: [:0]const u16,
    ) !void {
        try self._output_string(self, msg.ptr).err();
    }

    /// Verifies that all characters in a string can be output to the target device.
    pub fn testString(
        self: *const SimpleTextOutput,
        msg: [:0]const u16,
    ) bool {
        return self._test_string(self, msg.ptr) == .success;
    }

    /// The geometry of a output mode.
    pub const ModeGeometry = struct {
        rows: usize,
        columns: usize,
    };

    /// Returns information for an available text mode that the output device(s) supports.
    pub fn queryMode(
        self: *const SimpleTextOutput,
        /// The mode number to return information on.
        mode_number: usize,
    ) !ModeGeometry {
        var info: ModeGeometry = undefined;
        try self._query_mode(self, mode_number, &info.columns, &info.rows).err();
        return info;
    }

    /// Sets the output device(s) to a specified mode.
    pub fn setMode(
        self: *const SimpleTextOutput,
        /// The text mode to set.
        mode_number: usize,
    ) !void {
        try self._set_mode(self, mode_number).err();
    }

    pub const Attribute = packed struct(usize) {
        pub const Color = enum(u3) {
            black,
            blue,
            green,
            cyan,
            red,
            magenta,
            brown,
            lightgray,
        };

        foreground: Color = .lightgray,

        /// If true, `foreground` will use the bright variant of the color
        foreground_bright: bool = false,
        background: Color = .black,

        // this is a usize-sized bitfield, so we have to fill in the padding programmatically
        reserved: std.meta.Int(.unsigned, @bitSizeOf(usize) - 7) = 0,
    };

    /// Sets the background and foreground colors for the outputString() and clearScreen() functions.
    pub fn setAttribute(
        self: *const SimpleTextOutput,
        attribute: Attribute,
    ) !void {
        try self._set_attribute(self, attribute).err();
    }

    /// Clears the output device(s) display to the currently selected background color.
    pub fn clearScreen(self: *const SimpleTextOutput) !void {
        try self._clear_screen(self).err();
    }

    /// Sets the current coordinates of the cursor position.
    pub fn setCursorPosition(
        self: *const SimpleTextOutput,
        /// The column to move to. Must be less than the columns in the geometry of the mode.
        column: usize,
        /// The row to move to. Must be less than the rows in the geometry of the mode.
        row: usize,
    ) !void {
        try self._set_cursor_position(self, column, row).err();
    }

    /// Makes the cursor visible or invisible.
    pub fn enableCursor(
        self: *const SimpleTextOutput,
        visible: bool,
    ) !void {
        try self._enable_cursor(self, visible).err();
    }

    pub const guid align(8) = Guid{
        .time_low = 0x387477c2,
        .time_mid = 0x69c7,
        .time_high_and_version = 0x11d2,
        .clock_seq_high_and_reserved = 0x8e,
        .clock_seq_low = 0x39,
        .node = [_]u8{ 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b },
    };
    pub const boxdraw_horizontal: u16 = 0x2500;
    pub const boxdraw_vertical: u16 = 0x2502;
    pub const boxdraw_down_right: u16 = 0x250c;
    pub const boxdraw_down_left: u16 = 0x2510;
    pub const boxdraw_up_right: u16 = 0x2514;
    pub const boxdraw_up_left: u16 = 0x2518;
    pub const boxdraw_vertical_right: u16 = 0x251c;
    pub const boxdraw_vertical_left: u16 = 0x2524;
    pub const boxdraw_down_horizontal: u16 = 0x252c;
    pub const boxdraw_up_horizontal: u16 = 0x2534;
    pub const boxdraw_vertical_horizontal: u16 = 0x253c;
    pub const boxdraw_double_horizontal: u16 = 0x2550;
    pub const boxdraw_double_vertical: u16 = 0x2551;
    pub const boxdraw_down_right_double: u16 = 0x2552;
    pub const boxdraw_down_double_right: u16 = 0x2553;
    pub const boxdraw_double_down_right: u16 = 0x2554;
    pub const boxdraw_down_left_double: u16 = 0x2555;
    pub const boxdraw_down_double_left: u16 = 0x2556;
    pub const boxdraw_double_down_left: u16 = 0x2557;
    pub const boxdraw_up_right_double: u16 = 0x2558;
    pub const boxdraw_up_double_right: u16 = 0x2559;
    pub const boxdraw_double_up_right: u16 = 0x255a;
    pub const boxdraw_up_left_double: u16 = 0x255b;
    pub const boxdraw_up_double_left: u16 = 0x255c;
    pub const boxdraw_double_up_left: u16 = 0x255d;
    pub const boxdraw_vertical_right_double: u16 = 0x255e;
    pub const boxdraw_vertical_double_right: u16 = 0x255f;
    pub const boxdraw_double_vertical_right: u16 = 0x2560;
    pub const boxdraw_vertical_left_double: u16 = 0x2561;
    pub const boxdraw_vertical_double_left: u16 = 0x2562;
    pub const boxdraw_double_vertical_left: u16 = 0x2563;
    pub const boxdraw_down_horizontal_double: u16 = 0x2564;
    pub const boxdraw_down_double_horizontal: u16 = 0x2565;
    pub const boxdraw_double_down_horizontal: u16 = 0x2566;
    pub const boxdraw_up_horizontal_double: u16 = 0x2567;
    pub const boxdraw_up_double_horizontal: u16 = 0x2568;
    pub const boxdraw_double_up_horizontal: u16 = 0x2569;
    pub const boxdraw_vertical_horizontal_double: u16 = 0x256a;
    pub const boxdraw_vertical_double_horizontal: u16 = 0x256b;
    pub const boxdraw_double_vertical_horizontal: u16 = 0x256c;
    pub const blockelement_full_block: u16 = 0x2588;
    pub const blockelement_light_shade: u16 = 0x2591;
    pub const geometricshape_up_triangle: u16 = 0x25b2;
    pub const geometricshape_right_triangle: u16 = 0x25ba;
    pub const geometricshape_down_triangle: u16 = 0x25bc;
    pub const geometricshape_left_triangle: u16 = 0x25c4;
    pub const arrow_up: u16 = 0x2591;
    pub const arrow_down: u16 = 0x2593;
};

const std = @import("std");
const uefi = std.os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;
const cc = uefi.cc;
const Error = Status.Error;

/// Character output devices
pub const SimpleTextOutput = extern struct {
    _reset: *const fn (*SimpleTextOutput, bool) callconv(cc) Status,
    _output_string: *const fn (*SimpleTextOutput, [*:0]const u16) callconv(cc) Status,
    _test_string: *const fn (*const SimpleTextOutput, [*:0]const u16) callconv(cc) Status,
    _query_mode: *const fn (*const SimpleTextOutput, usize, *usize, *usize) callconv(cc) Status,
    _set_mode: *const fn (*SimpleTextOutput, usize) callconv(cc) Status,
    _set_attribute: *const fn (*SimpleTextOutput, usize) callconv(cc) Status,
    _clear_screen: *const fn (*SimpleTextOutput) callconv(cc) Status,
    _set_cursor_position: *const fn (*SimpleTextOutput, usize, usize) callconv(cc) Status,
    _enable_cursor: *const fn (*SimpleTextOutput, bool) callconv(cc) Status,
    mode: *Mode,

    pub const ResetError = uefi.UnexpectedError || error{DeviceError};
    pub const OutputStringError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };
    pub const QueryModeError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };
    pub const SetModeError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };
    pub const SetAttributeError = uefi.UnexpectedError || error{DeviceError};
    pub const ClearScreenError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };
    pub const SetCursorPositionError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };
    pub const EnableCursorError = uefi.UnexpectedError || error{
        DeviceError,
        Unsupported,
    };

    /// Resets the text output device hardware.
    pub fn reset(self: *SimpleTextOutput, verify: bool) ResetError!void {
        switch (self._reset(self, verify)) {
            .success => {},
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Writes a string to the output device.
    ///
    /// Returns `true` if the string was successfully written, `false` if an unknown glyph was encountered.
    pub fn outputString(self: *SimpleTextOutput, msg: [*:0]const u16) OutputStringError!bool {
        switch (self._output_string(self, msg)) {
            .success => return true,
            .warn_unknown_glyph => return false,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Verifies that all characters in a string can be output to the target device.
    pub fn testString(self: *const SimpleTextOutput, msg: [*:0]const u16) uefi.UnexpectedError!bool {
        switch (self._test_string(self, msg)) {
            .success => return true,
            .unsupported => return false,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Returns information for an available text mode that the output device(s) supports.
    pub fn queryMode(self: *const SimpleTextOutput, mode_number: usize) QueryModeError!Geometry {
        var geo: Geometry = undefined;
        switch (self._query_mode(self, mode_number, &geo.columns, &geo.rows)) {
            .success => return geo,
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Sets the output device(s) to a specified mode.
    pub fn setMode(self: *SimpleTextOutput, mode_number: usize) SetModeError!void {
        switch (self._set_mode(self, mode_number)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Sets the background and foreground colors for the outputString() and clearScreen() functions.
    pub fn setAttribute(self: *SimpleTextOutput, attribute: Attribute) SetAttributeError!void {
        const attr_as_num: u8 = @bitCast(attribute);
        switch (self._set_attribute(self, @intCast(attr_as_num))) {
            .success => {},
            .device_error => return Error.DeviceError,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Clears the output device(s) display to the currently selected background color.
    pub fn clearScreen(self: *SimpleTextOutput) ClearScreenError!void {
        switch (self._clear_screen(self)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Sets the current coordinates of the cursor position.
    pub fn setCursorPosition(
        self: *SimpleTextOutput,
        column: usize,
        row: usize,
    ) SetCursorPositionError!void {
        switch (self._set_cursor_position(self, column, row)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
    }

    /// Makes the cursor visible or invisible.
    pub fn enableCursor(self: *SimpleTextOutput, visible: bool) EnableCursorError!void {
        switch (self._enable_cursor(self, visible)) {
            .success => {},
            .device_error => return Error.DeviceError,
            .unsupported => return Error.Unsupported,
            else => |status| return uefi.unexpectedStatus(status),
        }
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

    pub const Attribute = packed struct(u8) {
        foreground: ForegroundColor = .white,
        background: BackgroundColor = .black,

        pub const ForegroundColor = enum(u4) {
            black,
            blue,
            green,
            cyan,
            red,
            magenta,
            brown,
            lightgray,
            darkgray,
            lightblue,
            lightgreen,
            lightcyan,
            lightred,
            lightmagenta,
            yellow,
            white,
        };

        pub const BackgroundColor = enum(u4) {
            black,
            blue,
            green,
            cyan,
            red,
            magenta,
            brown,
            lightgray,
        };
    };

    pub const Mode = extern struct {
        max_mode: u32, // specified as signed
        mode: u32, // specified as signed
        attribute: i32,
        cursor_column: i32,
        cursor_row: i32,
        cursor_visible: bool,
    };

    pub const Geometry = struct {
        columns: usize,
        rows: usize,
    };
};

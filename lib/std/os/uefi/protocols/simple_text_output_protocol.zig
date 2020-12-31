// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;
const Status = uefi.Status;

/// Character output devices
pub const SimpleTextOutputProtocol = extern struct {
    _reset: fn (*const SimpleTextOutputProtocol, bool) callconv(.C) Status,
    _output_string: fn (*const SimpleTextOutputProtocol, [*:0]const u16) callconv(.C) Status,
    _test_string: fn (*const SimpleTextOutputProtocol, [*:0]const u16) callconv(.C) Status,
    _query_mode: fn (*const SimpleTextOutputProtocol, usize, *usize, *usize) callconv(.C) Status,
    _set_mode: fn (*const SimpleTextOutputProtocol, usize) callconv(.C) Status,
    _set_attribute: fn (*const SimpleTextOutputProtocol, usize) callconv(.C) Status,
    _clear_screen: fn (*const SimpleTextOutputProtocol) callconv(.C) Status,
    _set_cursor_position: fn (*const SimpleTextOutputProtocol, usize, usize) callconv(.C) Status,
    _enable_cursor: fn (*const SimpleTextOutputProtocol, bool) callconv(.C) Status,
    mode: *SimpleTextOutputMode,

    /// Resets the text output device hardware.
    pub fn reset(self: *const SimpleTextOutputProtocol, verify: bool) Status {
        return self._reset(self, verify);
    }

    /// Writes a string to the output device.
    pub fn outputString(self: *const SimpleTextOutputProtocol, msg: [*:0]const u16) Status {
        return self._output_string(self, msg);
    }

    /// Verifies that all characters in a string can be output to the target device.
    pub fn testString(self: *const SimpleTextOutputProtocol, msg: [*:0]const u16) Status {
        return self._test_string(self, msg);
    }

    /// Returns information for an available text mode that the output device(s) supports.
    pub fn queryMode(self: *const SimpleTextOutputProtocol, mode_number: usize, columns: *usize, rows: *usize) Status {
        return self._query_mode(self, mode_number, columns, rows);
    }

    /// Sets the output device(s) to a specified mode.
    pub fn setMode(self: *const SimpleTextOutputProtocol, mode_number: usize) Status {
        return self._set_mode(self, mode_number);
    }

    /// Sets the background and foreground colors for the outputString() and clearScreen() functions.
    pub fn setAttribute(self: *const SimpleTextOutputProtocol, attribute: usize) Status {
        return self._set_attribute(self, attribute);
    }

    /// Clears the output device(s) display to the currently selected background color.
    pub fn clearScreen(self: *const SimpleTextOutputProtocol) Status {
        return self._clear_screen(self);
    }

    /// Sets the current coordinates of the cursor position.
    pub fn setCursorPosition(self: *const SimpleTextOutputProtocol, column: usize, row: usize) Status {
        return self._set_cursor_position(self, column, row);
    }

    /// Makes the cursor visible or invisible.
    pub fn enableCursor(self: *const SimpleTextOutputProtocol, visible: bool) Status {
        return self._enable_cursor(self, visible);
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
    pub const black: u8 = 0x00;
    pub const blue: u8 = 0x01;
    pub const green: u8 = 0x02;
    pub const cyan: u8 = 0x03;
    pub const red: u8 = 0x04;
    pub const magenta: u8 = 0x05;
    pub const brown: u8 = 0x06;
    pub const lightgray: u8 = 0x07;
    pub const bright: u8 = 0x08;
    pub const darkgray: u8 = 0x08;
    pub const lightblue: u8 = 0x09;
    pub const lightgreen: u8 = 0x0a;
    pub const lightcyan: u8 = 0x0b;
    pub const lightred: u8 = 0x0c;
    pub const lightmagenta: u8 = 0x0d;
    pub const yellow: u8 = 0x0e;
    pub const white: u8 = 0x0f;
    pub const background_black: u8 = 0x00;
    pub const background_blue: u8 = 0x10;
    pub const background_green: u8 = 0x20;
    pub const background_cyan: u8 = 0x30;
    pub const background_red: u8 = 0x40;
    pub const background_magenta: u8 = 0x50;
    pub const background_brown: u8 = 0x60;
    pub const background_lightgray: u8 = 0x70;
};

pub const SimpleTextOutputMode = extern struct {
    max_mode: u32, // specified as signed
    mode: u32, // specified as signed
    attribute: i32,
    cursor_column: i32,
    cursor_row: i32,
    cursor_visible: bool,
};

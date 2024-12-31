const std = @import("std");
const builtin = @import("builtin");
const File = std.fs.File;
const process = std.process;
const posix = std.posix;
const windows = std.os.windows;
const native_os = builtin.os.tag;

/// Detect suitable TTY configuration options for the given file (commonly stdout/stderr).
/// This includes feature checks for ANSI escape codes and the Windows console API, as well as
/// respecting the `NO_COLOR` and `CLICOLOR_FORCE` environment variables to override the default.
/// Will attempt to enable ANSI escape code support if necessary/possible.
pub fn detectConfig(file: File) Config {
    const force_color: ?bool = if (native_os == .wasi)
        null // wasi does not support environment variables
    else if (process.hasEnvVarConstant("NO_COLOR"))
        false
    else if (process.hasEnvVarConstant("CLICOLOR_FORCE"))
        true
    else
        null;

    if (force_color == false) return .no_color;

    if (file.getOrEnableAnsiEscapeSupport()) return .escape_codes;

    if (native_os == .windows and file.isTty()) {
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (windows.kernel32.GetConsoleScreenBufferInfo(file.handle, &info) == windows.FALSE) {
            return if (force_color == true) .escape_codes else .no_color;
        }
        return .{ .windows_api = .{
            .handle = file.handle,
            .reset_attributes = info.wAttributes,
        } };
    }

    return if (force_color == true) .escape_codes else .no_color;
}

pub const Color = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
    dim,
    bold,
    reset,
};

pub const Config = union(enum) {
    no_color,
    escape_codes,
    windows_api: if (native_os == .windows) WindowsContext else void,

    pub const WindowsContext = struct {
        handle: File.Handle,
        reset_attributes: u16,
    };

    pub fn setColor(
        config: Config,
        writer: anytype,
        color: Color,
    ) (@typeInfo(@TypeOf(writer.writeAll(""))).error_union.error_set ||
        windows.SetConsoleTextAttributeError)!void {
        nosuspend switch (config) {
            .no_color => return,
            .escape_codes => {
                const color_string = switch (color) {
                    .black => "\x1b[30m",
                    .red => "\x1b[31m",
                    .green => "\x1b[32m",
                    .yellow => "\x1b[33m",
                    .blue => "\x1b[34m",
                    .magenta => "\x1b[35m",
                    .cyan => "\x1b[36m",
                    .white => "\x1b[37m",
                    .bright_black => "\x1b[90m",
                    .bright_red => "\x1b[91m",
                    .bright_green => "\x1b[92m",
                    .bright_yellow => "\x1b[93m",
                    .bright_blue => "\x1b[94m",
                    .bright_magenta => "\x1b[95m",
                    .bright_cyan => "\x1b[96m",
                    .bright_white => "\x1b[97m",
                    .bold => "\x1b[1m",
                    .dim => "\x1b[2m",
                    .reset => "\x1b[0m",
                };
                try writer.writeAll(color_string);
            },
            .windows_api => |ctx| if (native_os == .windows) {
                const attributes = switch (color) {
                    .black => 0,
                    .red => windows.FOREGROUND_RED,
                    .green => windows.FOREGROUND_GREEN,
                    .yellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN,
                    .blue => windows.FOREGROUND_BLUE,
                    .magenta => windows.FOREGROUND_RED | windows.FOREGROUND_BLUE,
                    .cyan => windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE,
                    .white => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE,
                    .bright_black => windows.FOREGROUND_INTENSITY,
                    .bright_red => windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY,
                    .bright_green => windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                    .bright_yellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                    .bright_blue => windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                    .bright_magenta => windows.FOREGROUND_RED | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                    .bright_cyan => windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                    .bright_white, .bold => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                    // "dim" is not supported using basic character attributes, but let's still make it do *something*.
                    // This matches the old behavior of TTY.Color before the bright variants were added.
                    .dim => windows.FOREGROUND_INTENSITY,
                    .reset => ctx.reset_attributes,
                };
                try windows.SetConsoleTextAttribute(ctx.handle, attributes);
            } else {
                unreachable;
            },
        };
    }
};

/// Obtains the size of a terminal designated by the file descriptor.
pub fn getSize(file_descriptor: File) error{ NotATerminal, Unexpected }!struct { rows: u16, columns: u16 } {
    if (native_os == .windows) {
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (windows.kernel32.GetConsoleScreenBufferInfo(file_descriptor.handle, &info) != windows.FALSE) {
            // In the old Windows console, info.dwSize.Y is the line count of the
            // entire scrollback buffer, so we use this instead so that we
            // always get the size of the screen.
            const screen_height = info.srWindow.Bottom - info.srWindow.Top;
            return .{
                .rows = @intCast(screen_height),
                .columns = @intCast(info.dwSize.X),
            };
        } else {
            return error.NotATerminal;
        }
    } else {
        var winsize: posix.winsize = undefined;
        switch (posix.errno(posix.system.ioctl(file_descriptor.handle, posix.T.IOCGWINSZ, @intFromPtr(&winsize)))) {
            .SUCCESS => return .{ .rows = winsize.row, .columns = winsize.col },
            .NOTTY => return error.NotATerminal,
            .BADF, .FAULT, .INVAL => unreachable,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

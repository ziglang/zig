const std = @import("std");
const builtin = @import("builtin");
const File = std.fs.File;
const process = std.process;
const windows = std.os.windows;
const native_os = builtin.os.tag;

/// Detect suitable TTY configuration options for the given file (commonly stdout/stderr).
/// This includes feature checks for ANSI escape codes and the Windows console API, as well as
/// respecting the `NO_COLOR` environment variable.
pub fn detectConfig(file: File) Config {
    if (builtin.os.tag == .wasi) {
        // Per https://github.com/WebAssembly/WASI/issues/162 ANSI codes
        // aren't currently supported.
        return .no_color;
    } else if (process.hasEnvVarConstant("ZIG_DEBUG_COLOR")) {
        return .escape_codes;
    } else if (process.hasEnvVarConstant("NO_COLOR")) {
        return .no_color;
    } else if (file.supportsAnsiEscapeCodes()) {
        return .escape_codes;
    } else if (native_os == .windows and file.isTty()) {
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (windows.kernel32.GetConsoleScreenBufferInfo(file.handle, &info) != windows.TRUE) {
            // TODO: Should this return an error instead?
            return .no_color;
        }
        return .{ .windows_api = .{
            .handle = file.handle,
            .reset_attributes = info.wAttributes,
        } };
    }
    return .no_color;
}

pub const Color = enum {
    red,
    green,
    yellow,
    cyan,
    white,
    dim,
    bold,
    reset,
};

/// Provides simple functionality for manipulating the terminal in some way,
/// such as coloring text, etc.
pub const Config = union(enum) {
    no_color,
    escape_codes,
    windows_api: if (native_os == .windows) WindowsContext else void,

    pub const WindowsContext = struct {
        handle: File.Handle,
        reset_attributes: u16,
    };

    pub fn setColor(conf: Config, out_stream: anytype, color: Color) !void {
        nosuspend switch (conf) {
            .no_color => return,
            .escape_codes => {
                const color_string = switch (color) {
                    .red => "\x1b[31;1m",
                    .green => "\x1b[32;1m",
                    .yellow => "\x1b[33;1m",
                    .cyan => "\x1b[36;1m",
                    .white => "\x1b[37;1m",
                    .bold => "\x1b[1m",
                    .dim => "\x1b[2m",
                    .reset => "\x1b[0m",
                };
                try out_stream.writeAll(color_string);
            },
            .windows_api => |ctx| if (native_os == .windows) {
                const attributes = switch (color) {
                    .red => windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY,
                    .green => windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                    .yellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                    .cyan => windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                    .white, .bold => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                    .dim => windows.FOREGROUND_INTENSITY,
                    .reset => ctx.reset_attributes,
                };
                try windows.SetConsoleTextAttribute(ctx.handle, attributes);
            } else {
                unreachable;
            },
        };
    }

    pub fn writeDEC(conf: Config, writer: anytype, codepoint: u8) !void {
        const bytes = switch (conf) {
            .no_color, .windows_api => switch (codepoint) {
                0x50...0x5e => @as(*const [1]u8, &codepoint),
                0x6a => "+", // ┘
                0x6b => "+", // ┐
                0x6c => "+", // ┌
                0x6d => "+", // └
                0x6e => "+", // ┼
                0x71 => "-", // ─
                0x74 => "+", // ├
                0x75 => "+", // ┤
                0x76 => "+", // ┴
                0x77 => "+", // ┬
                0x78 => "|", // │
                else => " ", // TODO
            },
            .escape_codes => switch (codepoint) {
                // Here we avoid writing the DEC beginning sequence and
                // ending sequence in separate syscalls by putting the
                // beginning and ending sequence into the same string
                // literals, to prevent terminals ending up in bad states
                // in case a crash happens between syscalls.
                inline 0x50...0x7f => |x| "\x1B\x28\x30" ++ [1]u8{x} ++ "\x1B\x28\x42",
                else => unreachable,
            },
        };
        return writer.writeAll(bytes);
    }
};

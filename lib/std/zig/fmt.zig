const std = @import("std");
const mem = std.mem;

/// Print the string as a Zig identifier escaping it with @"" syntax if needed.
pub fn formatId(
    bytes: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    if (isValidId(bytes)) {
        return writer.writeAll(bytes);
    }
    try writer.writeAll("@\"");
    try formatEscapes(bytes, fmt, options, writer);
    try writer.writeByte('"');
}

/// Return a Formatter for a Zig identifier
pub fn fmtId(bytes: []const u8) std.fmt.Formatter(formatId) {
    return .{ .data = bytes };
}

pub fn isValidId(bytes: []const u8) bool {
    for (bytes) |c, i| {
        switch (c) {
            '_', 'a'...'z', 'A'...'Z' => {},
            '0'...'9' => if (i == 0) return false,
            else => return false,
        }
    }
    return std.zig.Token.getKeyword(bytes) == null;
}

pub fn formatEscapes(
    bytes: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    for (bytes) |byte| switch (byte) {
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        '\\' => try writer.writeAll("\\\\"),
        '"' => try writer.writeAll("\\\""),
        '\'' => try writer.writeAll("\\'"),
        ' ', '!', '#'...'&', '('...'[', ']'...'~' => try writer.writeByte(byte),
        // Use hex escapes for rest any unprintable characters.
        else => {
            try writer.writeAll("\\x");
            try std.fmt.formatInt(byte, 16, false, .{ .width = 2, .fill = '0' }, writer);
        },
    };
}

/// Return a Formatter for Zig Escapes
pub fn fmtEscapes(bytes: []const u8) std.fmt.Formatter(formatEscapes) {
    return .{ .data = bytes };
}

test "escape invalid identifiers" {
    try std.fmt.testFmt("@\"while\"", "{}", .{fmtId("while")});
    try std.fmt.testFmt("hello", "{}", .{fmtId("hello")});
    try std.fmt.testFmt("@\"11\\\"23\"", "{}", .{fmtId("11\"23")});
    try std.fmt.testFmt("@\"11\\x0f23\"", "{}", .{fmtId("11\x0F23")});
    try std.fmt.testFmt("\\x0f", "{}", .{fmtEscapes("\x0f")});
    try std.fmt.testFmt(
        \\" \\ hi \x07 \x11 \" derp \'"
    , "\"{}\"", .{fmtEscapes(" \\ hi \x07 \x11 \" derp '")});
}

const std = @import("std");

pub const std_options = struct {
    pub const logFn = log;
};

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
}

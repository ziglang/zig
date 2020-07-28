const std = @import("std");

pub fn main() anyerror!void {
    std.log.info(.app, "All your codebase are belong to us.\n", .{});
}

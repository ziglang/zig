const std = @import("std");

pub fn main() !void {
    try std.io.getStdOut().writeAll("Hello, World!\n");
}

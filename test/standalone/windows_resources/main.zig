const std = @import("std");

pub fn main() !void {
    std.debug.print("All your {s} belong to us.\n", .{"codebase"});
}

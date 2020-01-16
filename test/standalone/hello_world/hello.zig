const std = @import("std");

pub fn main() !void {
    const stdout_file = std.io.getStdOut();
    // If this program encounters pipe failure when printing to stdout, exit
    // with an error.
    try stdout_file.write("Hello, world!\n");
}

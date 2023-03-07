const std = @import("std");

// Stress test zerofill layout
var buffer: [0x1000000]u64 = [1]u64{0} ** 0x1000000;

pub fn main() anyerror!void {
    buffer[0x10] = 1;
    try std.io.getStdOut().writer().print("{d}, {d}, {d}\n", .{
        buffer[0],
        buffer[0x10],
        buffer[0x1000000 - 1],
    });
}

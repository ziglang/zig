const std = @import("std");

// Stress test zerofill layout
var buffer: [0x1000000]u64 = [1]u64{0} ** 0x1000000;

pub fn main() anyerror!void {
    var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});

    buffer[0x10] = 1;

    try stdout_writer.interface.print("{d}, {d}, {d}\n", .{
        // workaround the dreaded decl_val
        (&buffer)[0],
        (&buffer)[0x10],
        (&buffer)[0x1000000 - 1],
    });
}

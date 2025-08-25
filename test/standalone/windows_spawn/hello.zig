const std = @import("std");

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
    const stdout = &stdout_writer.interface;
    try stdout.writeAll("hello from exe\n");
}

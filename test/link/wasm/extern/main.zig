const std = @import("std");

extern const foo: u32;

pub fn main() void {
    var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
    stdout_writer.interface.print("Result: {d}", .{foo}) catch {};
}

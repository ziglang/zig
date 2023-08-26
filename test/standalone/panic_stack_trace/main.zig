//! This tests if there is a stack trace when we panic in a function
//! of a library without libc linked that is linked against an executable without libc linked.

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{"./exe"},
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    _ = std.mem.indexOf(u8, result.stderr, "@panic(\"hello\")").?;

    try std.fs.cwd().deleteFile("exe");
}

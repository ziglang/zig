//! This tests if there is a stack trace when we panic in a function
//! of a library without libc linked that is linked against an executable without libc linked.

const std = @import("std");
const exe_path = @import("exe_path");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const exe_path_exe = try std.mem.join(allocator, "", &.{ exe_path.exe_path, "/exe" });
    const exe_path_exe_path_zig = try std.mem.join(allocator, "", &.{ exe_path.exe_path, "/exe_path.zig" });

    var result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{exe_path_exe},
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    _ = std.mem.indexOf(u8, result.stderr, "@panic(\"hello\")").?;

    try std.fs.deleteFileAbsolute(exe_path_exe);
    try std.fs.deleteFileAbsolute(exe_path_exe_path_zig);
    try std.fs.deleteDirAbsolute(exe_path.exe_path);
}

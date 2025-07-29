const std = @import("std");

pub fn main() anyerror!void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer if (gpa.deinit() == .leak) @panic("found memory leaks");
    const allocator = gpa.allocator();

    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();
    _ = it.next() orelse unreachable; // skip binary name
    const exe_path = it.next() orelse unreachable;
    const symlink_path = it.next() orelse unreachable;

    // If `exe_path` is relative to our cwd, we need to convert it to be relative to the dirname of `symlink_path`.
    const exe_rel_path = try std.fs.path.relative(allocator, std.fs.path.dirname(symlink_path) orelse ".", exe_path);
    defer allocator.free(exe_rel_path);
    try std.fs.cwd().symLink(exe_rel_path, symlink_path, .{});
}

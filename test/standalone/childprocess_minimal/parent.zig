const std = @import("std");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const gpa = general_purpose_allocator.allocator();
    const args = [_][]const u8{ "zig-out/bin/child", "hello world" };
    var child_proc = std.ChildProcess.init(&args, gpa);
    const ret_val = try child_proc.spawnAndWait();
    try std.testing.expectEqual(ret_val, .{ .Exited = 0 });
}

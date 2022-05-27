const std = @import("std");

pub fn main() !void {
    const allocator = std.testing.allocator;
    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    std.debug.print("cwd: {s}\n", .{cwd});
    const args = [_][]const u8{ "zig-out/bin/child", "hello world" };
    var child_proc = std.ChildProcess.init(&args, allocator);
    const ret_val = try child_proc.spawnAndWait();
    try std.testing.expectEqual(ret_val, .{ .Exited = 0 });
}

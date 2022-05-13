const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var bytes: [1]u8 align(16) = undefined;
    var ptr = other;
    var frame = @asyncCall(&bytes, {}, ptr, .{});
    _ = frame;
    return error.TestFailed;
}
fn other() callconv(.Async) void {
    suspend {}
}
// run
// backend=stage1

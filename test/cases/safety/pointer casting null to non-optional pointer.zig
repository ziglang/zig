const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var c_ptr: [*c]u8 = 0;
    var zig_ptr: *u8 = c_ptr;
    _ = zig_ptr;
    return error.TestFailed;
}
// run
// backend=stage1

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var value: c_short = -1;
    var casted = @intCast(u32, value);
    _ = casted;
    return error.TestFailed;
}
// run
// backend=stage1
// target=native
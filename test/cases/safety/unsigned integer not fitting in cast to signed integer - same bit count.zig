const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var value: u8 = 245;
    var casted = @intCast(i8, value);
    _ = casted;
    return error.TestFailed;
}
// run
// backend=stage1,stage2
// target=native

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var zero: usize = 0;
    var b = @intToPtr(*u8, zero);
    _ = b;
    return error.TestFailed;
}
// run
// backend=stage1,stage2
// target=native

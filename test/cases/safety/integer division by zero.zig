const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    const x = div0(999, 0);
    _ = x;
    return error.TestFailed;
}
fn div0(a: i32, b: i32) i32 {
    return @divTrunc(a, b);
}
// run
// backend=stage1
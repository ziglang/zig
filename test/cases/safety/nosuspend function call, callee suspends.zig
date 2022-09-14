const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    _ = nosuspend add(101, 100);
    return error.TestFailed;
}
fn add(a: i32, b: i32) i32 {
    if (a > 100) {
        suspend {}
    }
    return a + b;
}
// run
// backend=stage1
// target=native

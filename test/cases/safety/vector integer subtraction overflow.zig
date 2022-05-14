const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var a: @Vector(4, u32) = [_]u32{ 1, 2, 8, 4 };
    var b: @Vector(4, u32) = [_]u32{ 5, 6, 7, 8 };
    const x = sub(b, a);
    _ = x;
    return error.TestFailed;
}
fn sub(a: @Vector(4, u32), b: @Vector(4, u32)) @Vector(4, u32) {
    return a - b;
}
// run
// backend=stage1
// target=native
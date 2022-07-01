const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var a: @Vector(4, i32) = [4]i32{111, 222, 333, 444};
    var b: @Vector(4, i32) = [4]i32{111, 0, 333, 444};
    const x = div0(a, b);
    _ = x;
    return error.TestFailed;
}
fn div0(a: @Vector(4, i32), b: @Vector(4, i32)) @Vector(4, i32) {
    return @divTrunc(a, b);
}
// run
// backend=stage1
// target=native
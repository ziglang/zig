const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var a: @Vector(4, i16) = [_]i16{ 1, -32768, 200, 4 };
    const x = neg(a);
    _ = x;
    return error.TestFailed;
}
fn neg(a: @Vector(4, i16)) @Vector(4, i16) {
    return -a;
}
// run
// backend=stage1
// target=native
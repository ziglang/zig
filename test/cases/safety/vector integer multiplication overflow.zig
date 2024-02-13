const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer overflow")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const a: @Vector(4, u8) = [_]u8{ 1, 2, 200, 4 };
    const b: @Vector(4, u8) = [_]u8{ 5, 6, 2, 8 };
    const x = mul(b, a);
    _ = x;
    return error.TestFailed;
}
fn mul(a: @Vector(4, u8), b: @Vector(4, u8)) @Vector(4, u8) {
    return a * b;
}
// run
// backend=llvm
// target=native

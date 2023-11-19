const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "division by zero")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const a: @Vector(4, i32) = [4]i32{ 111, 222, 333, 444 };
    const b: @Vector(4, i32) = [4]i32{ 111, 0, 333, 444 };
    const x = div0(a, b);
    _ = x;
    return error.TestFailed;
}
fn div0(a: @Vector(4, i32), b: @Vector(4, i32)) @Vector(4, i32) {
    return @divTrunc(a, b);
}
// run
// backend=llvm
// target=native

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer overflow")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const a: @Vector(4, u32) = [_]u32{ 1, 2, 8, 4 };
    const b: @Vector(4, u32) = [_]u32{ 5, 6, 7, 8 };
    const x = sub(b, a);
    _ = x;
    return error.TestFailed;
}
fn sub(a: @Vector(4, u32), b: @Vector(4, u32)) @Vector(4, u32) {
    return a - b;
}
// run
// backend=llvm
// target=native

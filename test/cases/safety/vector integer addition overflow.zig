const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .integer_overflow) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const a: @Vector(4, i32) = [_]i32{ 1, 2, 2147483643, 4 };
    const b: @Vector(4, i32) = [_]i32{ 5, 6, 7, 8 };
    const x = add(a, b);
    _ = x;
    return error.TestFailed;
}
fn add(a: @Vector(4, i32), b: @Vector(4, i32)) @Vector(4, i32) {
    return a + b;
}
// run
// backend=llvm
// target=native

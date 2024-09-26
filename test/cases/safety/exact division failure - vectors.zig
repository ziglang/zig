const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .exact_division_remainder) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const a: @Vector(4, i32) = [4]i32{ 111, 222, 333, 444 };
    const b: @Vector(4, i32) = [4]i32{ 111, 222, 333, 441 };
    const x = divExact(a, b);
    _ = x;
    return error.TestFailed;
}
fn divExact(a: @Vector(4, i32), b: @Vector(4, i32)) @Vector(4, i32) {
    return @divExact(a, b);
}
// run
// backend=llvm
// target=native

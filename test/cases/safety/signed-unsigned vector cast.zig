const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .negative_to_unsigned) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x: @Vector(4, i32) = @splat(-2147483647);
    _ = &x;
    const y: @Vector(4, u32) = @intCast(x);
    _ = y;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

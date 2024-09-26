const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x: @Vector(4, u32) = @splat(0xdeadbeef);
    _ = &x;
    const y: @Vector(4, u16) = @intCast(x);
    _ = y;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

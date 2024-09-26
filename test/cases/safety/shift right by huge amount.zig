const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .shift_rhs_too_big) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x: u24 = 42;
    var y: u5 = 24;
    _ = .{ &x, &y };
    const z = x << y;
    _ = z;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

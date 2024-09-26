const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .integer_overflow) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const x = sub(10, 20);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn sub(a: u16, b: u16) u16 {
    return a - b;
}
// run
// backend=llvm
// target=native

const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .integer_overflow) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const x = neg(-32768);
    if (x == 32767) return error.Whatever;
    return error.TestFailed;
}
fn neg(a: i16) i16 {
    return -a;
}
// run
// backend=llvm
// target=native

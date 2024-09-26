const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .reached_unreachable) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    unreachable;
}
// run
// backend=llvm
// target=native

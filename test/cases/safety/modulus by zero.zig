const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .divide_by_zero) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const x = mod0(999, 0);
    _ = x;
    return error.TestFailed;
}
fn mod0(a: i32, b: i32) i32 {
    return @mod(a, b);
}
// run
// backend=llvm
// target=native

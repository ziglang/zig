const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    bar(1, 1);
    return error.TestFailed;
}

fn bar(one: u1, not_zero: i32) void {
    const x = one << @intCast(not_zero);
    _ = x;
}
// run
// backend=llvm
// target=native

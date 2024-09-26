const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const x = shorten_cast(200);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shorten_cast(x: i32) i8 {
    return @intCast(x);
}
// run
// backend=llvm
// target=native

const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .negative_to_unsigned) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const x = unsigned_cast(-10);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn unsigned_cast(x: i32) u32 {
    return @intCast(x);
}
// run
// backend=llvm
// target=native

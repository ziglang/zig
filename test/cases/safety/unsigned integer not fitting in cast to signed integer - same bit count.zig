const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var value: u8 = 245;
    _ = &value;
    const casted: i8 = @intCast(value);
    _ = casted;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

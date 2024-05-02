pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_truncated_data', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
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

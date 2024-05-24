pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .unwrapped_error) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.unwrapped_error', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    bar() catch unreachable;
    return error.TestFailed;
}
fn bar() !void {
    return error.Whatever;
}
// run
// backend=llvm
// target=native

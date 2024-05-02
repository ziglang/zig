pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .reached_unreachable) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.reached_unreachable', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
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

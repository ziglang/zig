pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .shift_amt_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.shift_amt_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var x: u24 = 42;
    var y: u5 = 24;
    _ = .{ &x, &y };
    const z = x << y;
    _ = z;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

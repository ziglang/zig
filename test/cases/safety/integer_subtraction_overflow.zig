pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .sub_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.sub_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = sub(10, 20);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn sub(a: u16, b: u16) u16 {
    return a - b;
}
// run
// backend=llvm
// target=native

pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .div_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.div_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = div(-32768, -1);
    if (x == 32767) return error.Whatever;
    return error.TestFailed;
}
fn div(a: i16, b: i16) i16 {
    return @divTrunc(a, b);
}
// run
// backend=llvm
// target=native

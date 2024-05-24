pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .shl_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.shl_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = shl(-16385, 1);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shl(a: i16, b: u4) i16 {
    return @shlExact(a, b);
}
// run
// backend=llvm
// target=native

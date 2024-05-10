pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .shr_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.shr_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = shr(0b0010111111111111, 3);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shr(a: u16, b: u4) u16 {
    return @shrExact(a, b);
}
// run
// backend=llvm
// target=native

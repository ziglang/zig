pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .shr_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.shr_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = shr(-16385, 1);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shr(a: i16, b: u4) i16 {
    return @shrExact(a, b);
}
// run
// backend=llvm
// target=native

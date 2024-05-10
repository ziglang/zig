pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .sub_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.sub_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = neg(-32768);
    if (x == 32767) return error.Whatever;
    return error.TestFailed;
}
fn neg(a: i16) i16 {
    return -a;
}
// run
// backend=llvm
// target=native

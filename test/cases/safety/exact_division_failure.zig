pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .div_with_remainder) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.div_with_remainder', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = divExact(10, 3);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn divExact(a: i32, b: i32) i32 {
    return @divExact(a, b);
}
// run
// backend=llvm
// target=native

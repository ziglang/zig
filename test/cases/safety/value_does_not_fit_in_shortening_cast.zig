pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_truncated_data', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = shorten_cast(200);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shorten_cast(x: i32) i8 {
    return @intCast(x);
}
// run
// backend=llvm
// target=native

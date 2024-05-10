pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_unsigned_from_negative) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_unsigned_from_negative', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = unsigned_cast(-10);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn unsigned_cast(x: i32) u32 {
    return @intCast(x);
}
// run
// backend=llvm
// target=native

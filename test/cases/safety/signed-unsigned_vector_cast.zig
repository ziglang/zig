pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .cast_to_unsigned_from_negative) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_unsigned_from_negative', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var x: @Vector(4, i32) = @splat(-2147483647);
    _ = &x;
    const y: @Vector(4, u32) = @intCast(x);
    _ = y;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

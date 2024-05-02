pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_truncated_data', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var x: @Vector(4, u32) = @splat(0xdeadbeef);
    _ = &x;
    const y: @Vector(4, u16) = @intCast(x);
    _ = y;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

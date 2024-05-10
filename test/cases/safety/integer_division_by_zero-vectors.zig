pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .divided_by_zero) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.divided_by_zero', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const a: @Vector(4, i32) = [4]i32{ 111, 222, 333, 444 };
    const b: @Vector(4, i32) = [4]i32{ 111, 0, 333, 444 };
    const x = div0(a, b);
    _ = x;
    return error.TestFailed;
}
fn div0(a: @Vector(4, i32), b: @Vector(4, i32)) @Vector(4, i32) {
    return @divTrunc(a, b);
}
// run
// backend=llvm
// target=native

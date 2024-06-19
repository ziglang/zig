pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .div_with_remainder) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.div_with_remainder', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const a: @Vector(4, i32) = [4]i32{ 111, 222, 333, 444 };
    const b: @Vector(4, i32) = [4]i32{ 111, 222, 333, 441 };
    const x = divExact(a, b);
    _ = x;
    return error.TestFailed;
}
fn divExact(a: @Vector(4, i32), b: @Vector(4, i32)) @Vector(4, i32) {
    return @divExact(a, b);
}
// run
// backend=llvm
// target=native

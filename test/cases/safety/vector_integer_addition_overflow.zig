pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .add_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.add_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const a: @Vector(4, i32) = [_]i32{ 1, 2, 2147483643, 4 };
    const b: @Vector(4, i32) = [_]i32{ 5, 6, 7, 8 };
    const x = add(a, b);
    _ = x;
    return error.TestFailed;
}
fn add(a: @Vector(4, i32), b: @Vector(4, i32)) @Vector(4, i32) {
    return a + b;
}
// run
// backend=llvm
// target=native

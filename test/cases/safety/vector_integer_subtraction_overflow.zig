pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .sub_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.sub_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const a: @Vector(4, u32) = [_]u32{ 1, 2, 8, 4 };
    const b: @Vector(4, u32) = [_]u32{ 5, 6, 7, 8 };
    const x = sub(b, a);
    _ = x;
    return error.TestFailed;
}
fn sub(a: @Vector(4, u32), b: @Vector(4, u32)) @Vector(4, u32) {
    return a - b;
}
// run
// backend=llvm
// target=native

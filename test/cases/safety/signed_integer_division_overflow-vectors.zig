pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .div_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.div_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const a: @Vector(4, i16) = [_]i16{ 1, 2, -32768, 4 };
    const b: @Vector(4, i16) = [_]i16{ 1, 2, -1, 4 };
    const x = div(a, b);
    if (x[2] == 32767) return error.Whatever;
    return error.TestFailed;
}
fn div(a: @Vector(4, i16), b: @Vector(4, i16)) @Vector(4, i16) {
    return @divTrunc(a, b);
}
// run
// backend=llvm
// target=native

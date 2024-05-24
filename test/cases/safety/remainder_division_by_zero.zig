pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .divided_by_zero) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.divided_by_zero', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    if (return) {}
    const x = rem0(999, 0);
    _ = x;
    return error.TestFailed;
}
fn rem0(a: i32, b: i32) i32 {
    return @rem(a, b);
}
// run
// backend=llvm
// target=native

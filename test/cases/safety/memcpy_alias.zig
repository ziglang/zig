pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .memcpy_argument_aliasing) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.memcpy_argument_aliasing', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var buffer = [2]u8{ 1, 2 } ** 5;
    var len: usize = 5;
    _ = &len;
    @memcpy(buffer[0..len], buffer[4 .. 4 + len]);
}
// run
// backend=llvm
// target=native

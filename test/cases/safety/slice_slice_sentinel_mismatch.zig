pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .mismatched_null_sentinel) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.mismatched_null_sentinel', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var buf: [4]u8 = .{ 1, 2, 3, 4 };
    const slice = buf[0..];
    const slice2 = slice[0..3 :0];
    _ = slice2;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

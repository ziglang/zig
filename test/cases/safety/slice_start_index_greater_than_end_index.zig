pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .accessed_out_of_order_extra) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.accessed_out_of_order_extra', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var a: usize = 1;
    var b: usize = 10;
    _ = .{ &a, &b };
    var buf: [16]u8 = undefined;

    const slice = buf[b..a];
    _ = slice;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

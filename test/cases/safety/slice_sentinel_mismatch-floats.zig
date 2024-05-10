pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .mismatched_sentinel) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.mismatched_sentinel', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var buf: [4]f32 = .{ 1, 2, 3, 4 };
    const slice = buf[0..3 :1.2];
    _ = slice;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

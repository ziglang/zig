pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_truncated_data) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_truncated_data', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var value: u8 = 245;
    _ = &value;
    const casted: i8 = @intCast(value);
    _ = casted;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

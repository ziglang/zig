pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .accessed_out_of_bounds) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.accessed_out_of_bounds', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var buf = [4]u8{ 'a', 'b', 'c', 0 };
    const input: []u8 = &buf;
    const slice = input[0..4 :0];
    _ = slice;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

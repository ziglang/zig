pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .add_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.add_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var buffer = [6]u8{ 1, 2, 3, 4, 5, 6 };
    var len = buffer.len;
    _ = &len;
    @memset(buffer[0..len], undefined);
    var x: u8 = buffer[1];
    x += buffer[2];
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

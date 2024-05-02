pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .mismatched_memcpy_argument_lengths) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.mismatched_memcpy_argument_lengths', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var buffer = [2]u8{ 1, 2 } ** 5;
    var len: usize = 5;
    _ = &len;
    @memcpy(buffer[0..len], buffer[len .. len + 4]);
}
// run
// backend=llvm
// target=native

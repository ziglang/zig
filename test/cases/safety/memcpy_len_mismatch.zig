const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .memcpy_len_mismatch) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var buffer = [2]u8{ 1, 2 } ** 5;
    var len: usize = 5;
    _ = &len;
    @memcpy(buffer[0..len], buffer[len .. len + 4]);
}
// run
// backend=llvm
// target=native

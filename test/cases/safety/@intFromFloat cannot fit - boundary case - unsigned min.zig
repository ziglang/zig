const std = @import("std");
pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer part of floating point value out of bounds")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
var x: f32 = -1;
pub fn main() !void {
    _ = @as(u8, @intFromFloat(x));
    return error.TestFailed;
}
// run
// backend=stage2,llvm
// target=x86_64-linux

const std = @import("std");
pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer part of floating point value out of bounds")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
var x: @Vector(2, f32) = .{ 100, -513 };
pub fn main() !void {
    _ = @as(@Vector(2, i10), @intFromFloat(x));
    return error.TestFailed;
}
// run
// backend=stage2,llvm
// target=native

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "incorrect alignment")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var x: usize = 5;
    var y = @intToPtr([*]align(4) u8, x);
    _ = y;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

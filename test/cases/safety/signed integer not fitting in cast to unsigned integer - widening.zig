const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "attempt to cast negative value to unsigned integer")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var value: c_short = -1;
    var casted = @intCast(u32, value);
    _ = casted;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

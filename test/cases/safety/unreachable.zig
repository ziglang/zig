const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = stack_trace;
    _ = ret_addr;
    if (std.mem.eql(u8, message, "reached unreachable code")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    unreachable;
}
// run
// backend=llvm
// target=native

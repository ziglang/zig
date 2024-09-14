const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "index out of bounds: index 1, len 0")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

var end: usize = 1;
pub fn main() void {
    _ = @as([]u8, &.{})[0..end];
}

// run
// backend=llvm
// target=native

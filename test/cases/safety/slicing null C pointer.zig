const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    var ptr: [*c]const u32 = null;
    var slice = ptr[0..3];
    _ = slice;
    return error.TestFailed;
}
// run
// backend=stage1
// target=native
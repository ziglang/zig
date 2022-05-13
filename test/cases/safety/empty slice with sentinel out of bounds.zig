const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "index out of bounds")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf_zero = [0]u8{};
    const input: []u8 = &buf_zero;
    const slice = input[0..0 :0];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=stage1

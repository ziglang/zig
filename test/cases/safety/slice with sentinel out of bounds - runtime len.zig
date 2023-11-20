const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "index out of bounds: index 5, len 4")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf = [4]u8{ 'a', 'b', 'c', 0 };
    const input: []u8 = &buf;
    var len: usize = 4;
    _ = &len;
    const slice = input[0..len :0];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "index out of bounds: index 12, len 5")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf: [5]u8 = undefined;
    var a: u32 = 6;
    _ = &a;
    _ = buf[a..][0..a];
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

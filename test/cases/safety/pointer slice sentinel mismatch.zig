const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "sentinel mismatch")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf: [4]u8 = undefined;
    const ptr: [*]u8 = &buf;
    const slice = ptr[0..3 :0];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=stage1

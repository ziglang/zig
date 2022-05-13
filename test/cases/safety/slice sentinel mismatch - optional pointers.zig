const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "sentinel mismatch")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf: [4]?*i32 = undefined;
    const slice = buf[0..3 :null];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=stage1

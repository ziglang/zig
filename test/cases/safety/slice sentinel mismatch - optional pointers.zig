const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "sentinel mismatch: expected null, found i32@10")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf: [4]?*i32 = .{ @intToPtr(*i32, 4), @intToPtr(*i32, 8), @intToPtr(*i32, 12), @intToPtr(*i32, 16) };
    const slice = buf[0..3 :null];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

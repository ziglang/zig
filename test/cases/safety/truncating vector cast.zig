const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer cast truncated bits")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x = @splat(4, @as(u32, 0xdeadbeef));
    var y = @intCast(@Vector(4, u16), x);
    _ = y;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

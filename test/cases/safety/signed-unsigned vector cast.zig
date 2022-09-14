const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "attempt to cast negative value to unsigned integer")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x = @splat(4, @as(i32, -2147483647));
    var y = @intCast(@Vector(4, u32), x);
    _ = y;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

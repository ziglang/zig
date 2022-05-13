const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    bar(1, 1);
    return error.TestFailed;
}

fn bar(one: u1, not_zero: i32) void {
    var x = one << @intCast(u0, not_zero);
    _ = x;
}
// run
// backend=stage1
const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    const x = shorten_cast(1);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shorten_cast(x: u8) u0 {
    return @intCast(u0, x);
}
// run
// backend=stage1
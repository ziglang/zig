const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    bar(9999) catch {};
    return error.TestFailed;
}
fn bar(x: u16) anyerror {
    return @intToError(x);
}
// run
// backend=stage1
// target=native
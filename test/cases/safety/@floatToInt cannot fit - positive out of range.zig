const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    baz(bar(256.2));
    return error.TestFailed;
}
fn bar(a: f32) u8 {
    return @floatToInt(u8, a);
}
fn baz(_: u8) void { }
// run
// backend=stage1
const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    baz(bar(-129.1));
    return error.TestFailed;
}
fn bar(a: f32) i8 {
    return @floatToInt(i8, a);
}
fn baz(_: i8) void { }
// run
// backend=stage1
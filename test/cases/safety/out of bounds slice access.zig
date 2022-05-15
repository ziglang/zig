const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    const a = [_]i32{1, 2, 3, 4};
    baz(bar(&a));
    return error.TestFailed;
}
fn bar(a: []const i32) i32 {
    return a[4];
}
fn baz(_: i32) void { }
// run
// backend=stage1
// target=native
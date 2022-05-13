const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
const Foo = enum {
    A,
    B,
    C,
};
pub fn main() !void {
    baz(bar(3));
    return error.TestFailed;
}
fn bar(a: u2) Foo {
    return @intToEnum(Foo, a);
}
fn baz(_: Foo) void {}
// run
// backend=stage1

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "invalid enum value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
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
    return @enumFromInt(a);
}
fn baz(_: Foo) void {}

// run
// backend=llvm
// target=native

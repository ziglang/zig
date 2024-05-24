pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_enum_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_enum_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
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

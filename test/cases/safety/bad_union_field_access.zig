pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .accessed_inactive_field) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.accessed_inactive_field', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
const Foo = union {
    float: f32,
    int: u32,
};
pub fn main() !void {
    var f = Foo{ .int = 42 };
    bar(&f);
    return error.TestFailed;
}
fn bar(f: *Foo) void {
    f.float = 12.34;
}
// run
// backend=llvm
// target=native

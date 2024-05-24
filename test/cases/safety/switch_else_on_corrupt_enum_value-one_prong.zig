pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_enum_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_enum_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
const E = enum(u32) {
    one = 1,
    two = 2,
};
pub fn main() !void {
    var a: E = undefined;
    @as(*u32, @ptrCast(&a)).* = 255;
    switch (a) {
        .one => @panic("one"),
        else => @panic("else"),
    }
}
// run
// backend=llvm
// target=native

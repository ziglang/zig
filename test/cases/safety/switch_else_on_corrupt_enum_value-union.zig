pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .corrupt_switch) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.corrupt_switch', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
const E = enum(u16) {
    one = 1,
    two = 2,
    _,
};
const U = union(E) {
    one: u16,
    two: u16,
};
pub fn main() !void {
    var a: U = undefined;
    @as(*align(@alignOf(U)) u32, @ptrCast(&a)).* = 0xFFFF_FFFF;
    switch (a) {
        .one => @panic("one"),
        else => @panic("else"),
    }
}
// run
// backend=llvm
// target=native

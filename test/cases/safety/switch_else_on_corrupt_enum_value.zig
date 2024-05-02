pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .corrupt_switch) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.corrupt_switch', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
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
        else => @panic("else"),
    }
}
// run
// backend=llvm
// target=native

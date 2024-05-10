pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .corrupt_switch) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.corrupt_switch', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
const E = enum(u32) {
    X = 1,
    Y = 2,
};
pub fn main() !void {
    var e: E = undefined;
    @memset(@as([*]u8, @ptrCast(&e))[0..@sizeOf(E)], 0x55);
    switch (e) {
        .X, .Y => @breakpoint(),
    }
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

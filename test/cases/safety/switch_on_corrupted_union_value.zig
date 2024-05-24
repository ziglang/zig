pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .corrupt_switch) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.corrupt_switch', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
const U = union(enum(u32)) {
    X: u8,
    Y: i8,
};
pub fn main() !void {
    var u: U = undefined;
    @memset(@as([*]u8, @ptrCast(&u))[0..@sizeOf(U)], 0x55);
    switch (u) {
        .X, .Y => @breakpoint(),
    }
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

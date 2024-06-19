pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_ptr_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_ptr_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var x: usize = 5;
    _ = &x;
    const y: [*]align(4) u8 = @ptrFromInt(x);
    _ = y;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

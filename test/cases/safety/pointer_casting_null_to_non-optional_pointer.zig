pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_ptr_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_ptr_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var c_ptr: [*c]u8 = 0;
    _ = &c_ptr;
    const zig_ptr: *u8 = c_ptr;
    _ = zig_ptr;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

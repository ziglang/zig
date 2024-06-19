pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_ptr_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_ptr_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
fn getNullPtr() ?*const anyopaque {
    return null;
}
pub fn main() !void {
    const null_ptr: ?*const anyopaque = getNullPtr();
    const required_ptr: *align(1) const fn () void = @ptrCast(null_ptr);
    _ = required_ptr;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

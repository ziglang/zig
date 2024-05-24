pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .accessed_null_value) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.accessed_null_value', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var ptr: ?*i32 = null;
    _ = &ptr;
    const b = ptr.?;
    _ = b;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

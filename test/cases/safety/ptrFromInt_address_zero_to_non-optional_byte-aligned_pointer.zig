pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_ptr_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_ptr_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var zero: usize = 0;
    _ = &zero;
    const b: *u8 = @ptrFromInt(zero);
    _ = b;
    return error.TestFailed;
}
// run
// backend=llvm
// target=native

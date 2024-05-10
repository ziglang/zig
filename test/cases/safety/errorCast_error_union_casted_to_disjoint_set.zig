pub fn panicNew(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .cast_to_error_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_error_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const bar: error{Foo}!i32 = @errorCast(foo());
    _ = &bar;
    return error.TestFailed;
}
fn foo() anyerror!i32 {
    return error.Bar;
}
// run
// backend=llvm
// target=native

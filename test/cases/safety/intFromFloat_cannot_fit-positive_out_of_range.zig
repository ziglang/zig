pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .cast_to_int_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_int_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    baz(bar(256.2));
    return error.TestFailed;
}
fn bar(a: f32) u8 {
    return @intFromFloat(a);
}
fn baz(_: u8) void {}
// run
// backend=llvm
// target=native

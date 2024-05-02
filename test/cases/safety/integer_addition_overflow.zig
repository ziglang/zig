pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .add_overflowed) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.add_overflowed', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = add(65530, 10);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn add(a: u16, b: u16) u16 {
    return a + b;
}
// run
// backend=llvm
// target=native

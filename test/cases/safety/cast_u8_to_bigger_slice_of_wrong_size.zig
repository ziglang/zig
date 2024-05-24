pub fn panic2(comptime cause: std.builtin.PanicCause, _: anytype) noreturn {
    if (cause == .div_with_remainder) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.div_with_remainder', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    const x = widenSlice(&[_]u8{ 1, 2, 3, 4, 5 });
    if (x.len == 0) return error.Whatever;
    return error.TestFailed;
}
fn widenSlice(slice: []align(1) const u8) []align(1) const i32 {
    return std.mem.bytesAsSlice(i32, slice);
}
// run
// backend=llvm
// target=native

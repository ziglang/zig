pub fn panicNew(comptime cause: std.builtin.PanicCause, _: std.builtin.PanicData(cause)) noreturn {
    if (cause == .cast_to_ptr_from_invalid) {
        std.process.exit(0);
    }
    std.debug.print(@src().file ++ ": Expected panic cause: '.cast_to_ptr_from_invalid', found panic cause: '." ++ @tagName(cause) ++ "'\n", .{});
    std.process.exit(1);
}
const std = @import("std");
pub fn main() !void {
    var array align(4) = [_]u32{ 0x11111111, 0x11111111 };
    const bytes = std.mem.sliceAsBytes(array[0..]);
    if (foo(bytes) != 0x11111111) return error.Wrong;
    return error.TestFailed;
}
fn foo(bytes: []u8) u32 {
    const slice4 = bytes[1..5];
    const aligned: *align(4) [4]u8 = @alignCast(slice4);
    const int_slice = std.mem.bytesAsSlice(u32, aligned);
    return int_slice[0];
}
// run
// backend=llvm
// target=native

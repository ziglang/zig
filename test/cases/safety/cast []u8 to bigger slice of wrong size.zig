const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    const x = widenSlice(&[_]u8{1, 2, 3, 4, 5});
    if (x.len == 0) return error.Whatever;
    return error.TestFailed;
}
fn widenSlice(slice: []align(1) const u8) []align(1) const i32 {
    return std.mem.bytesAsSlice(i32, slice);
}
// run
// backend=stage1
// target=native
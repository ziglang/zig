const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    const x = unsigned_cast(-10);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn unsigned_cast(x: i32) u32 {
    return @intCast(u32, x);
}
// run
// backend=stage1,stage2
// target=native

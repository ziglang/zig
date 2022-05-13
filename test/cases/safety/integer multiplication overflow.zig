const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    const x = mul(300, 6000);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn mul(a: u16, b: u16) u16 {
    return a * b;
}
// run
// backend=stage1
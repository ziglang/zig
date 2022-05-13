const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    const x = div(-32768, -1);
    if (x == 32767) return error.Whatever;
    return error.TestFailed;
}
fn div(a: i16, b: i16) i16 {
    return @divTrunc(a, b);
}
// run
// backend=stage1
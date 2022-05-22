const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    const x = shl(-16385, 1);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shl(a: i16, b: u4) i16 {
    return @shlExact(a, b);
}
// run
// backend=stage1,stage2
// target=native

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    const x = neg(-32768);
    if (x == 32767) return error.Whatever;
    return error.TestFailed;
}
fn neg(a: i16) i16 {
    return -a;
}
// run
// backend=stage1,stage2
// target=native

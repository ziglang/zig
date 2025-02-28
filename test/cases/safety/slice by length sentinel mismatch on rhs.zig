const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "sentinel mismatch: expected 1, found 0")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var buf: [4:0]u8 = .{ 1, 2, 3, 4 };
    const slice = buf[0.. :1][0..2];
    _ = slice;
    return error.TestFailed;
}
// run
// backend=stage2,llvm
// target=native

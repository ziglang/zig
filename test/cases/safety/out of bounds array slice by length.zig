const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "index out of bounds: index 16, len 5")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var buf: [5]u8 = undefined;
    _ = buf[foo(6)..][0..10];
    return error.TestFailed;
}
fn foo(a: u32) u32 {
    return a;
}
// run
// backend=llvm
// target=native

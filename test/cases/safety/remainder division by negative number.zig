const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "remainder division by zero or negative value")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const x = div0(999, -1);
    _ = x;
    return error.TestFailed;
}
fn div0(a: i32, b: i32) i32 {
    return @rem(a, b);
}
// run
// backend=llvm
// target=native

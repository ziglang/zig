const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "index out of bounds: index 4, len 4")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    const a = [_]i32{ 1, 2, 3, 4 };
    baz(bar(&a));
    return error.TestFailed;
}
fn bar(a: []const i32) i32 {
    return a[4];
}
fn baz(_: i32) void {}
// run
// backend=llvm
// target=native

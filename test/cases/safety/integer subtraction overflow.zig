const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer overflow")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const x = sub(10, 20);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn sub(a: u16, b: u16) u16 {
    return a - b;
}
// run
// backend=llvm
// target=native

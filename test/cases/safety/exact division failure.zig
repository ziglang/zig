const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "exact division produced remainder")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const x = divExact(10, 3);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn divExact(a: i32, b: i32) i32 {
    return @divExact(a, b);
}
// run
// backend=llvm
// target=native

const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "left shift overflowed bits")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const x = shl(0b0010111111111111, 3);
    if (x == 0) return error.Whatever;
    return error.TestFailed;
}
fn shl(a: u16, b: u4) u16 {
    return @shlExact(a, b);
}
// run
// backend=llvm
// target=native

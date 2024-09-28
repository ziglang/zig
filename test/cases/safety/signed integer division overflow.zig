const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer overflow")) {
        std.process.exit(0);
    }
    std.process.exit(1);
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
// backend=llvm
// target=native

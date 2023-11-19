const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer overflow")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    const a: @Vector(4, i16) = [_]i16{ 1, 2, -32768, 4 };
    const b: @Vector(4, i16) = [_]i16{ 1, 2, -1, 4 };
    const x = div(a, b);
    if (x[2] == 32767) return error.Whatever;
    return error.TestFailed;
}
fn div(a: @Vector(4, i16), b: @Vector(4, i16)) @Vector(4, i16) {
    return @divTrunc(a, b);
}
// run
// backend=llvm
// target=native

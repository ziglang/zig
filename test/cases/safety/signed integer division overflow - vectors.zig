const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

pub fn main() !void {
    var a: @Vector(4, i16) = [_]i16{ 1, 2, -32768, 4 };
    var b: @Vector(4, i16) = [_]i16{ 1, 2, -1, 4 };
    const x = div(a, b);
    if (x[2] == 32767) return error.Whatever;
    return error.TestFailed;
}
fn div(a: @Vector(4, i16), b: @Vector(4, i16)) @Vector(4, i16) {
    return @divTrunc(a, b);
}
// run
// backend=stage1
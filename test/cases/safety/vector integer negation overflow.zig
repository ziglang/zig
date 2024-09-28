const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer overflow")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    var a: @Vector(4, i16) = [_]i16{ 1, -32768, 200, 4 };
    _ = &a;
    const x = neg(a);
    _ = x;
    return error.TestFailed;
}
fn neg(a: @Vector(4, i16)) @Vector(4, i16) {
    return -a;
}
// run
// backend=llvm
// target=native

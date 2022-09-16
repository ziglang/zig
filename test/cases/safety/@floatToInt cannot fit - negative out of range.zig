const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "integer part of floating point value out of bounds")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
pub fn main() !void {
    baz(bar(-129.1));
    return error.TestFailed;
}
fn bar(a: f32) i8 {
    return @floatToInt(i8, a);
}
fn baz(_: i8) void { }
// run
// backend=llvm
// target=native

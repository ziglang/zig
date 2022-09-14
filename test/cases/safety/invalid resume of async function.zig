const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
pub fn main() !void {
    var p = async suspendOnce();
    resume p; //ok
    resume p; //bad
    return error.TestFailed;
}
fn suspendOnce() void {
    suspend {}
}
// run
// backend=stage1
// target=native

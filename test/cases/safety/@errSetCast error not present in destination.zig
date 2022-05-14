const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
const Set1 = error{A, B};
const Set2 = error{A, C};
pub fn main() !void {
    foo(Set1.B) catch {};
    return error.TestFailed;
}
fn foo(set1: Set1) Set2 {
    return @errSetCast(Set2, set1);
}
// run
// backend=stage1
// target=native
const std = @import("std");

pub const Panic = struct {
    pub const call = panic;
    pub const unwrapError = std.debug.FormattedPanic.unwrapError;
    pub const outOfBounds = std.debug.FormattedPanic.outOfBounds;
    pub const startGreaterThanEnd = std.debug.FormattedPanic.startGreaterThanEnd;
    pub const sentinelMismatch = std.debug.FormattedPanic.sentinelMismatch;
    pub const inactiveUnionField = std.debug.FormattedPanic.inactiveUnionField;
    pub const messages = std.debug.FormattedPanic.messages;
};

fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (std.mem.eql(u8, message, "invalid error code")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}
const Set1 = error{ A, B };
const Set2 = error{ A, C };
pub fn main() !void {
    foo(Set1.B) catch {};
    return error.TestFailed;
}
fn foo(set1: Set1) Set2 {
    return @errorCast(set1);
}
// run
// backend=llvm
// target=native

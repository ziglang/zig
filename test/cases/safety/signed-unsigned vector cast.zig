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
    if (std.mem.eql(u8, message, "attempt to cast negative value to unsigned integer")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x: @Vector(4, i32) = @splat(-2147483647);
    _ = &x;
    const y: @Vector(4, u32) = @intCast(x);
    _ = y;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

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
    if (std.mem.eql(u8, message, "shift amount is greater than the type size")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var x: u24 = 42;
    var y: u5 = 24;
    _ = .{ &x, &y };
    const z = x >> y;
    _ = z;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

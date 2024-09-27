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
    if (std.mem.eql(u8, message, "start index 10 is larger than end index 1")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var a: usize = 1;
    var b: usize = 10;
    _ = .{ &a, &b };
    var buf: [16]u8 = undefined;

    const slice = buf[b..a];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

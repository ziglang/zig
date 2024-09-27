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
    if (std.mem.eql(u8, message, "cast causes pointer to be null")) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

pub fn main() !void {
    var c_ptr: [*c]u8 = 0;
    _ = &c_ptr;
    const zig_ptr: *u8 = c_ptr;
    _ = zig_ptr;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

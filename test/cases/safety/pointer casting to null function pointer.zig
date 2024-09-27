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

fn getNullPtr() ?*const anyopaque {
    return null;
}
pub fn main() !void {
    const null_ptr: ?*const anyopaque = getNullPtr();
    const required_ptr: *align(1) const fn () void = @ptrCast(null_ptr);
    _ = required_ptr;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native

pub const Panic = struct {
    pub const call = badPanicSignature;
    pub const sentinelMismatch = std.debug.FormattedPanic.sentinelMismatch;
    pub const unwrapError = std.debug.FormattedPanic.unwrapError;
    pub const outOfBounds = std.debug.FormattedPanic.outOfBounds;
    pub const startGreaterThanEnd = std.debug.FormattedPanic.startGreaterThanEnd;
    pub const inactiveUnionField = std.debug.FormattedPanic.inactiveUnionField;
    pub const messages = std.debug.FormattedPanic.messages;
};

fn badPanicSignature(msg: []const u8, bad1: usize, bad2: void) noreturn {
    _ = msg;
    _ = bad1;
    _ = bad2;
    @trap();
}

export fn foo(a: u8) void {
    @setRuntimeSafety(true);
    _ = a + 1; // safety check to reference the panic handler
}

const std = @import("std");

// error
//
// :2:9: error: expected type 'fn ([]const u8, ?*builtin.StackTrace, ?usize) noreturn', found 'fn ([]const u8, usize, void) noreturn'
// :2:9: note: parameter 1 'usize' cannot cast into '?*builtin.StackTrace'

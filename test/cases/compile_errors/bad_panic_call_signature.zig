const simple_panic = std.debug.simple_panic;
pub const panic = struct {
    pub fn call(msg: []const u8, bad1: usize, bad2: void) noreturn {
        _ = msg;
        _ = bad1;
        _ = bad2;
        @trap();
    }
    pub const sentinelMismatch = simple_panic.sentinelMismatch;
    pub const unwrapError = simple_panic.unwrapError;
    pub const outOfBounds = simple_panic.outOfBounds;
    pub const startGreaterThanEnd = simple_panic.startGreaterThanEnd;
    pub const inactiveUnionField = simple_panic.inactiveUnionField;
    pub const reachedUnreachable = simple_panic.reachedUnreachable;
    pub const unwrapNull = simple_panic.unwrapNull;
    pub const castToNull = simple_panic.castToNull;
    pub const incorrectAlignment = simple_panic.incorrectAlignment;
    pub const invalidErrorCode = simple_panic.invalidErrorCode;
    pub const castTruncatedData = simple_panic.castTruncatedData;
    pub const negativeToUnsigned = simple_panic.negativeToUnsigned;
    pub const integerOverflow = simple_panic.integerOverflow;
    pub const shlOverflow = simple_panic.shlOverflow;
    pub const shrOverflow = simple_panic.shrOverflow;
    pub const divideByZero = simple_panic.divideByZero;
    pub const exactDivisionRemainder = simple_panic.exactDivisionRemainder;
    pub const integerPartOutOfBounds = simple_panic.integerPartOutOfBounds;
    pub const corruptSwitch = simple_panic.corruptSwitch;
    pub const shiftRhsTooBig = simple_panic.shiftRhsTooBig;
    pub const invalidEnumValue = simple_panic.invalidEnumValue;
    pub const forLenMismatch = simple_panic.forLenMismatch;
    pub const memcpyLenMismatch = simple_panic.memcpyLenMismatch;
    pub const memcpyAlias = simple_panic.memcpyAlias;
    pub const noreturnReturned = simple_panic.noreturnReturned;
};

export fn foo(a: u8) void {
    @setRuntimeSafety(true);
    _ = a + 1; // safety check to reference the panic handler
}

const std = @import("std");

// error
//
// :3:9: error: expected type 'fn ([]const u8, ?*builtin.StackTrace, ?usize) noreturn', found 'fn ([]const u8, usize, void) noreturn'
// :3:9: note: parameter 1 'usize' cannot cast into '?*builtin.StackTrace'

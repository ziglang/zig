const simple_panic = std.debug.simple_panic;
pub const panic = struct {
    pub fn call(msg: []const u8, bad: usize) noreturn {
        _ = msg;
        _ = bad;
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
    pub const integerOutOfBounds = simple_panic.integerOutOfBounds;
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
    pub const copyLenMismatch = simple_panic.copyLenMismatch;
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
// :3:9: error: expected type 'fn ([]const u8, ?usize) noreturn', found 'fn ([]const u8, usize) noreturn'
// :3:9: note: parameter 1 'usize' cannot cast into '?usize'

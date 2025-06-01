const simple_panic = std.debug.simple_panic;
pub const panic = struct {
    pub fn sentinelMismatch() void {} // invalid
    pub const call = simple_panic.call;
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

export fn foo(arr: *const [2]u8) void {
    @setRuntimeSafety(true);
    _ = arr[0..1 :0];
}

const std = @import("std");

// error
//
// :3:9: error: expected type 'fn (anytype, anytype) noreturn', found 'fn () void'
// :3:9: note: non-generic function cannot cast into a generic function

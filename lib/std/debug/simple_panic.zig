//! This namespace is the default one used by the Zig compiler to emit various
//! kinds of safety panics, due to the logic in `std.builtin.panic`.
//!
//! Since Zig does not have interfaces, this file serves as an example template
//! for users to provide their own alternative panic handling.
//!
//! As an alternative, see `std.debug.FullPanic`.

const std = @import("../std.zig");

/// Prints the message to stderr without a newline and then traps.
///
/// Explicit calls to `@panic` lower to calling this function.
pub fn call(msg: []const u8, ra: ?usize) noreturn {
    @branchHint(.cold);
    _ = ra;
    std.debug.lockStdErr();
    const stderr = std.io.getStdErr();
    stderr.writeAll(msg) catch {};
    @trap();
}

pub fn sentinelMismatch(expected: anytype, found: @TypeOf(expected)) noreturn {
    _ = found;
    call("sentinel mismatch", null);
}

pub fn unwrapError(err: anyerror) noreturn {
    _ = &err;
    call("attempt to unwrap error", null);
}

pub fn outOfBounds(index: usize, len: usize) noreturn {
    _ = index;
    _ = len;
    call("index out of bounds", null);
}

pub fn startGreaterThanEnd(start: usize, end: usize) noreturn {
    _ = start;
    _ = end;
    call("start index is larger than end index", null);
}

pub fn inactiveUnionField(active: anytype, accessed: @TypeOf(active)) noreturn {
    _ = accessed;
    call("access of inactive union field", null);
}

pub fn sliceCastLenRemainder(src_len: usize) noreturn {
    _ = src_len;
    call("slice length does not divide exactly into destination elements", null);
}

pub fn reachedUnreachable() noreturn {
    call("reached unreachable code", null);
}

pub fn unwrapNull() noreturn {
    call("attempt to use null value", null);
}

pub fn castToNull() noreturn {
    call("cast causes pointer to be null", null);
}

pub fn incorrectAlignment() noreturn {
    call("incorrect alignment", null);
}

pub fn invalidErrorCode() noreturn {
    call("invalid error code", null);
}

pub fn castTruncatedData() noreturn {
    call("integer cast truncated bits", null);
}

pub fn negativeToUnsigned() noreturn {
    call("attempt to cast negative value to unsigned integer", null);
}

pub fn integerOverflow() noreturn {
    call("integer overflow", null);
}

pub fn shlOverflow() noreturn {
    call("left shift overflowed bits", null);
}

pub fn shrOverflow() noreturn {
    call("right shift overflowed bits", null);
}

pub fn divideByZero() noreturn {
    call("division by zero", null);
}

pub fn exactDivisionRemainder() noreturn {
    call("exact division produced remainder", null);
}

pub fn integerPartOutOfBounds() noreturn {
    call("integer part of floating point value out of bounds", null);
}

pub fn corruptSwitch() noreturn {
    call("switch on corrupt value", null);
}

pub fn shiftRhsTooBig() noreturn {
    call("shift amount is greater than the type size", null);
}

pub fn invalidEnumValue() noreturn {
    call("invalid enum value", null);
}

pub fn forLenMismatch() noreturn {
    call("for loop over objects with non-equal lengths", null);
}

pub fn memcpyLenMismatch() noreturn {
    call("@memcpy arguments have non-equal lengths", null);
}

pub fn memcpyAlias() noreturn {
    call("@memcpy arguments alias", null);
}

pub fn noreturnReturned() noreturn {
    call("'noreturn' function returned", null);
}

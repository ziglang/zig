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

/// To be deleted after zig1.wasm update.
pub const messages = struct {
    pub const reached_unreachable = "reached unreachable code";
    pub const unwrap_null = "attempt to use null value";
    pub const cast_to_null = "cast causes pointer to be null";
    pub const incorrect_alignment = "incorrect alignment";
    pub const invalid_error_code = "invalid error code";
    pub const cast_truncated_data = "integer cast truncated bits";
    pub const negative_to_unsigned = "attempt to cast negative value to unsigned integer";
    pub const integer_overflow = "integer overflow";
    pub const shl_overflow = "left shift overflowed bits";
    pub const shr_overflow = "right shift overflowed bits";
    pub const divide_by_zero = "division by zero";
    pub const exact_division_remainder = "exact division produced remainder";
    pub const integer_part_out_of_bounds = "integer part of floating point value out of bounds";
    pub const corrupt_switch = "switch on corrupt value";
    pub const shift_rhs_too_big = "shift amount is greater than the type size";
    pub const invalid_enum_value = "invalid enum value";
    pub const for_len_mismatch = "for loop over objects with non-equal lengths";
    pub const memcpy_len_mismatch = "@memcpy arguments have non-equal lengths";
    pub const memcpy_alias = "@memcpy arguments alias";
    pub const noreturn_returned = "'noreturn' function returned";
};

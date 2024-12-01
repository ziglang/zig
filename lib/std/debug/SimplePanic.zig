//! This namespace is the default one used by the Zig compiler to emit various
//! kinds of safety panics, due to the logic in `std.builtin.Panic`.
//!
//! Since Zig does not have interfaces, this file serves as an example template
//! for users to provide their own alternative panic handling.
//!
//! As an alternative, see `std.debug.FormattedPanic`.

const std = @import("../std.zig");

/// Prints the message to stderr without a newline and then traps.
///
/// Explicit calls to `@panic` lower to calling this function.
pub fn call(msg: []const u8, ert: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    @branchHint(.cold);
    _ = ert;
    _ = ra;
    std.debug.lockStdErr();
    const stderr = std.io.getStdErr();
    stderr.writeAll(msg) catch {};
    @trap();
}

pub fn sentinelMismatch(expected: anytype, found: @TypeOf(expected)) noreturn {
    _ = found;
    call("sentinel mismatch", null, null);
}

pub fn unwrapError(ert: ?*std.builtin.StackTrace, err: anyerror) noreturn {
    _ = ert;
    _ = &err;
    call("attempt to unwrap error", null, null);
}

pub fn outOfBounds(index: usize, len: usize) noreturn {
    _ = index;
    _ = len;
    call("index out of bounds", null, null);
}

pub fn startGreaterThanEnd(start: usize, end: usize) noreturn {
    _ = start;
    _ = end;
    call("start index is larger than end index", null, null);
}

pub fn inactiveUnionField(active: anytype, accessed: @TypeOf(active)) noreturn {
    _ = accessed;
    call("access of inactive union field", null, null);
}

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

    /// To be deleted after zig1.wasm is updated.
    pub const inactive_union_field = "access of inactive union field";
    /// To be deleted after zig1.wasm is updated.
    pub const sentinel_mismatch = "sentinel mismatch";
    /// To be deleted after zig1.wasm is updated.
    pub const unwrap_error = "attempt to unwrap error";
    /// To be deleted after zig1.wasm is updated.
    pub const index_out_of_bounds = "index out of bounds";
    /// To be deleted after zig1.wasm is updated.
    pub const start_index_greater_than_end = "start index is larger than end index";
    /// To be deleted after zig1.wasm is updated.
    pub const unreach = reached_unreachable;
};

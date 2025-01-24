//! This namespace can be used with `pub const panic = std.debug.no_panic;` in the root file.
//! It emits as little code as possible, for testing purposes.
//!
//! For a functional alternative, see `std.debug.FullPanic`.

const std = @import("../std.zig");

pub fn call(_: []const u8, _: ?usize) noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn sentinelMismatch(_: anytype, _: anytype) noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn unwrapError(_: anyerror) noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn outOfBounds(_: usize, _: usize) noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn startGreaterThanEnd(_: usize, _: usize) noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn inactiveUnionField(_: anytype, _: anytype) noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn reachedUnreachable() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn unwrapNull() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn castToNull() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn incorrectAlignment() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn invalidErrorCode() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn castTruncatedData() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn negativeToUnsigned() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn integerOverflow() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn shlOverflow() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn shrOverflow() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn divideByZero() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn exactDivisionRemainder() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn integerPartOutOfBounds() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn corruptSwitch() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn shiftRhsTooBig() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn invalidEnumValue() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn forLenMismatch() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn memcpyLenMismatch() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn memcpyAlias() noreturn {
    @branchHint(.cold);
    @trap();
}

pub fn noreturnReturned() noreturn {
    @branchHint(.cold);
    @trap();
}

/// To be deleted after zig1.wasm update.
pub const messages = struct {
    pub const reached_unreachable = "";
    pub const unwrap_null = "";
    pub const cast_to_null = "";
    pub const incorrect_alignment = "";
    pub const invalid_error_code = "";
    pub const cast_truncated_data = "";
    pub const negative_to_unsigned = "";
    pub const integer_overflow = "";
    pub const shl_overflow = "";
    pub const shr_overflow = "";
    pub const divide_by_zero = "";
    pub const exact_division_remainder = "";
    pub const integer_part_out_of_bounds = "";
    pub const corrupt_switch = "";
    pub const shift_rhs_too_big = "";
    pub const invalid_enum_value = "";
    pub const for_len_mismatch = "";
    pub const memcpy_len_mismatch = "";
    pub const memcpy_alias = "";
    pub const noreturn_returned = "";
};

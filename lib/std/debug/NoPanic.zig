//! This namespace can be used with `pub const Panic = std.debug.NoPanic;` in the root file.
//! It emits as little code as possible, for testing purposes.
//!
//! For a functional alternative, see `std.debug.FormattedPanic`.

const std = @import("../std.zig");

pub fn call(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @branchHint(.cold);
    @trap();
}

pub inline fn sentinelMismatch(_: anytype, _: anytype) noreturn {
    @branchHint(.cold);
    @trap();
}

pub inline fn unwrapError(_: ?*std.builtin.StackTrace, _: anyerror) noreturn {
    @branchHint(.cold);
    @trap();
}

pub inline fn outOfBounds(_: usize, _: usize) noreturn {
    @branchHint(.cold);
    @trap();
}

pub inline fn startGreaterThanEnd(_: usize, _: usize) noreturn {
    @branchHint(.cold);
    @trap();
}

pub inline fn inactiveUnionField(_: anytype, _: anytype) noreturn {
    @branchHint(.cold);
    @trap();
}

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

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

pub fn sliceCastLenRemainder(_: usize) noreturn {
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

const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    @export(__negsi2, .{ .name = "__negsi2", .linkage = linkage });
    @export(__negdi2, .{ .name = "__negdi2", .linkage = linkage });
    @export(__negti2, .{ .name = "__negti2", .linkage = linkage });
}

// neg - negate (the number)
// - negXi2 for unoptimized little and big endian

// sfffffff = 2^31-1
// two's complement inverting bits and add 1 would result in -INT_MIN == 0
// => -INT_MIN = -2^31 forbidden

// * size optimized builds
// * machines that dont support carry operations

inline fn negXi2(comptime T: type, a: T) T {
    @setRuntimeSafety(builtin.is_test);
    return -a;
}

pub fn __negsi2(a: i32) callconv(.C) i32 {
    return negXi2(i32, a);
}

pub fn __negdi2(a: i64) callconv(.C) i64 {
    return negXi2(i64, a);
}

pub fn __negti2(a: i128) callconv(.C) i128 {
    return negXi2(i128, a);
}

test {
    _ = @import("negsi2_test.zig");
    _ = @import("negdi2_test.zig");
    _ = @import("negti2_test.zig");
}

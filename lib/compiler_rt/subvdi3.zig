const common = @import("./common.zig");
const testing = @import("std").testing;

pub const panic = common.panic;

comptime {
    @export(&__subvdi3, .{ .name = "__subvdi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subvdi3(a: i64, b: i64) callconv(.c) i64 {
    const sum = a -% b;
    // Overflow occurred iff the operands have opposite signs, and the sign of the
    // sum is the opposite of the lhs sign.
    if (((a ^ b) & (sum ^ a)) < 0) @panic("compiler-rt: integer overflow");
    return sum;
}

test "subvdi3" {
    // min i64 = -9223372036854775808
    // max i64 = 9223372036854775807
    // TODO write panic handler for testing panics
    // try test__subvdi3(-9223372036854775808, -1, -1); // panic
    // try test__addvdi3(9223372036854775807, 1, 1);  // panic
    try testing.expectEqual(-9223372036854775808, __subvdi3(-9223372036854775807, 1));
    try testing.expectEqual(9223372036854775807, __subvdi3(9223372036854775806, -1));
}

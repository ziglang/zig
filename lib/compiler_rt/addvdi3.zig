const common = @import("./common.zig");
const testing = @import("std").testing;

pub const panic = common.panic;

comptime {
    @export(&__addvdi3, .{ .name = "__addvdi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __addvdi3(a: i64, b: i64) callconv(.c) i64 {
    const sum = a +% b;
    // Overflow occurred iff both operands have the same sign, and the sign of the sum does
    // not match it. In other words, iff the sum sign is not the sign of either operand.
    if (((sum ^ a) & (sum ^ b)) < 0) @panic("compiler-rt: integer overflow");
    return sum;
}

test "addvdi3" {
    // const min: i64 = -9223372036854775808
    // const max: i64 = 9223372036854775807
    // TODO write panic handler for testing panics
    // try test__addvdi3(-9223372036854775808, -1, -1); // panic
    // try test__addvdi3(9223372036854775807, 1, 1);  // panic
    try testing.expectEqual(-9223372036854775808, __addvdi3(-9223372036854775807, -1));
    try testing.expectEqual(9223372036854775807, __addvdi3(9223372036854775806, 1));
}

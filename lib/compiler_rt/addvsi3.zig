const common = @import("./common.zig");
const testing = @import("std").testing;

pub const panic = common.panic;

comptime {
    @export(&__addvsi3, .{ .name = "__addvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __addvsi3(a: i32, b: i32) callconv(.c) i32 {
    const sum = a +% b;
    // Overflow occurred iff both operands have the same sign, and the sign of the sum does
    // not match it. In other words, iff the sum sign is not the sign of either operand.
    if (((sum ^ a) & (sum ^ b)) < 0) @panic("compiler-rt: integer overflow");
    return sum;
}

test "addvsi3" {
    // const min: i32 = -2147483648
    // const max: i32 = 2147483647
    // TODO write panic handler for testing panics
    // try test__addvsi3(-2147483648, -1, -1); // panic
    // try test__addvsi3(2147483647, 1, 1);  // panic
    try testing.expectEqual(-2147483648, __addvsi3(-2147483647, -1));
    try testing.expectEqual(2147483647, __addvsi3(2147483646, 1));
}

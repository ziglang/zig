const common = @import("./common.zig");
const testing = @import("std").testing;

pub const panic = common.panic;

comptime {
    @export(&__subvsi3, .{ .name = "__subvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subvsi3(a: i32, b: i32) callconv(.c) i32 {
    const sum = a -% b;
    // Overflow occurred iff the operands have opposite signs, and the sign of the
    // sum is the opposite of the lhs sign.
    if (((a ^ b) & (sum ^ a)) < 0) @panic("compiler-rt: integer overflow");
    return sum;
}

test "subvsi3" {
    // min i32 = -2147483648
    // max i32 = 2147483647
    // TODO write panic handler for testing panics
    // try test__subvsi3(-2147483648, -1, -1); // panic
    // try test__subvsi3(2147483647, 1, 1);  // panic
    try testing.expectEqual(-2147483648, __subvsi3(-2147483647, 1));
    try testing.expectEqual(2147483647, __subvsi3(2147483646, -1));
}

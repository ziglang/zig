const subv = @import("subo.zig");
const common = @import("./common.zig");
const testing = @import("std").testing;

pub const panic = common.panic;

comptime {
    @export(&__subvsi3, .{ .name = "__subvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __subvsi3(a: i32, b: i32) callconv(.c) i32 {
    var overflow: c_int = 0;
    const sum = subv.__subosi4(a, b, &overflow);
    if (overflow != 0) @panic("compiler-rt: integer overflow");
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

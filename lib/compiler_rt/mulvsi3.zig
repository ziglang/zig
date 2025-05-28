const mulv = @import("mulo.zig");
const common = @import("./common.zig");
const testing = @import("std").testing;

pub const panic = common.panic;

comptime {
    @export(&__mulvsi3, .{ .name = "__mulvsi3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __mulvsi3(a: i32, b: i32) callconv(.c) i32 {
    var overflow: c_int = 0;
    const sum = mulv.__mulosi4(a, b, &overflow);
    if (overflow == 1) @panic("compiler-rt: integer overflow");
    return sum;
}

test "mulvsi3" {
    // min i32 = -2147483648
    // max i32 = 2147483647
    // TODO write panic handler for testing panics
    // try test__mulvsi3(-2147483648, -1, -1); // panic
    // try test__mulvsi3(2147483647, 1, 1);  // panic
    try testing.expectEqual(-2147483648, __mulvsi3(-1073741824, 2));
    try testing.expectEqual(2147483646, __mulvsi3(1073741823, 2)); // one too less for corner case 2147483647
}

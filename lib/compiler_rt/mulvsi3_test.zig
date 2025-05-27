const testing = @import("std").testing;

const __mulvsi3 = @import("mulvsi3.zig").__mulvsi3;

fn test__mulvsi3(a: i32, b: i32, expected: i32) !void {
    const result = __mulvsi3(a, b);
    try testing.expectEqual(expected, result);
}

test "mulvsi3" {
    // min i32 = -2147483648
    // max i32 = 2147483647
    // TODO write panic handler for testing panics
    // try test__mulvsi3(-2147483648, -1, -1); // panic
    // try test__mulvsi3(2147483647, 1, 1);  // panic
    try test__mulvsi3(-1073741824, 2, -2147483648);
    try test__mulvsi3(1073741823, 2, 2147483646); // one too less for corner case 2147483647
}

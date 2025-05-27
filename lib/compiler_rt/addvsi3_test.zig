const testing = @import("std").testing;

const __addvsi3 = @import("addvsi3.zig").__addvsi3;

fn test__addvsi3(a: i32, b: i32, expected: i32) !void {
    const result = __addvsi3(a, b);
    try testing.expectEqual(expected, result);
}

test "addvsi3" {
    // min i32 = -2147483648
    // max i32 = 2147483647
    // TODO write panic handler for testing panics
    // try test__addvsi3(-2147483648, -1, -1); // panic
    // try test__addvsi3(2147483647, 1, 1);  // panic
    try test__addvsi3(-2147483647, -1, -2147483648);
    try test__addvsi3(2147483646, 1, 2147483647);
}

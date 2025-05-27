const testing = @import("std").testing;

const __subvsi3 = @import("subvsi3.zig").__subvsi3;

fn test__subvsi3(a: i32, b: i32, expected: i32) !void {
    const result = __subvsi3(a, b);
    try testing.expectEqual(expected, result);
}

test "subvsi3" {
    // min i32 = -2147483648
    // max i32 = 2147483647
    // TODO write panic handler for testing panics
    // try test__subvsi3(-2147483648, -1, -1); // panic
    // try test__subvsi3(2147483647, 1, 1);  // panic
    try test__subvsi3(-2147483647, 1, -2147483648);
    try test__subvsi3(2147483646, -1, 2147483647);
}

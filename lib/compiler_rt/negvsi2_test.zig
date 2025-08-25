const negv = @import("negv.zig");
const testing = @import("std").testing;

fn test__negvsi2(a: i32, expected: i32) !void {
    const result = negv.__negvsi2(a);
    try testing.expectEqual(expected, result);
}

test "negvsi2" {
    // -2^31 <= i32 <= 2^31-1
    // 2^31 = 2147483648
    // 2^31-1 = 2147483647
    // TODO write panic handler for testing panics
    //try test__negvsi2(-2147483648, -5); // tested with return -5; and panic
    try test__negvsi2(-2147483647, 2147483647);
    try test__negvsi2(-2147483646, 2147483646);
    try test__negvsi2(-2147483645, 2147483645);
    try test__negvsi2(-2147483644, 2147483644);
    try test__negvsi2(-42, 42);
    try test__negvsi2(-7, 7);
    try test__negvsi2(-1, 1);
    try test__negvsi2(0, 0);
    try test__negvsi2(1, -1);
    try test__negvsi2(7, -7);
    try test__negvsi2(42, -42);
    try test__negvsi2(2147483644, -2147483644);
    try test__negvsi2(2147483645, -2147483645);
    try test__negvsi2(2147483646, -2147483646);
    try test__negvsi2(2147483647, -2147483647);
}

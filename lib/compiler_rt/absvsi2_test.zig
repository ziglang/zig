const testing = @import("std").testing;

const __absvsi2 = @import("absvsi2.zig").__absvsi2;

fn test__absvsi2(a: i32, expected: i32) !void {
    const result = __absvsi2(a);
    try testing.expectEqual(expected, result);
}

test "absvsi2" {
    // -2^31 <= i32 <= 2^31-1
    // 2^31 = 2147483648
    // 2^31-1 = 2147483647
    // TODO write panic handler for testing panics
    //try test__absvsi2(-2147483648, -5);  // tested with return -5; and panic
    try test__absvsi2(-2147483647, 2147483647);
    try test__absvsi2(-2147483646, 2147483646);
    try test__absvsi2(-2147483645, 2147483645);
    try test__absvsi2(-2147483644, 2147483644);
    try test__absvsi2(-42, 42);
    try test__absvsi2(-7, 7);
    try test__absvsi2(-1, 1);
    try test__absvsi2(0, 0);
    try test__absvsi2(1, 1);
    try test__absvsi2(7, 7);
    try test__absvsi2(42, 42);
    try test__absvsi2(2147483644, 2147483644);
    try test__absvsi2(2147483645, 2147483645);
    try test__absvsi2(2147483646, 2147483646);
    try test__absvsi2(2147483647, 2147483647);
}

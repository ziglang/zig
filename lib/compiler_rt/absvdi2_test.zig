const testing = @import("std").testing;

const __absvdi2 = @import("absvdi2.zig").__absvdi2;

fn test__absvdi2(a: i64, expected: i64) !void {
    const result = __absvdi2(a);
    try testing.expectEqual(expected, result);
}

test "absvdi2" {
    // -2^63 <= i64 <= 2^63-1
    // 2^63 = 9223372036854775808
    // 2^63-1 = 9223372036854775807
    // TODO write panic handler for testing panics
    //try test__absvdi2(-9223372036854775808, -5); // tested with return -5; and panic
    try test__absvdi2(-9223372036854775807, 9223372036854775807);
    try test__absvdi2(-9223372036854775806, 9223372036854775806);
    try test__absvdi2(-9223372036854775805, 9223372036854775805);
    try test__absvdi2(-9223372036854775804, 9223372036854775804);
    try test__absvdi2(-42, 42);
    try test__absvdi2(-7, 7);
    try test__absvdi2(-1, 1);
    try test__absvdi2(0, 0);
    try test__absvdi2(1, 1);
    try test__absvdi2(7, 7);
    try test__absvdi2(42, 42);
    try test__absvdi2(9223372036854775804, 9223372036854775804);
    try test__absvdi2(9223372036854775805, 9223372036854775805);
    try test__absvdi2(9223372036854775806, 9223372036854775806);
    try test__absvdi2(9223372036854775807, 9223372036854775807);
}

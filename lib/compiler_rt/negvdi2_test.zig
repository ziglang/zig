const negv = @import("negv.zig");
const testing = @import("std").testing;

fn test__negvdi2(a: i64, expected: i64) !void {
    const result = negv.__negvdi2(a);
    try testing.expectEqual(expected, result);
}

test "negvdi2" {
    // -2^63 <= i64 <= 2^63-1
    // 2^63 = 9223372036854775808
    // 2^63-1 = 9223372036854775807
    // TODO write panic handler for testing panics
    //try test__negvdi2(-9223372036854775808, -5); // tested with return -5; and panic
    try test__negvdi2(-9223372036854775807, 9223372036854775807);
    try test__negvdi2(-9223372036854775806, 9223372036854775806);
    try test__negvdi2(-9223372036854775805, 9223372036854775805);
    try test__negvdi2(-9223372036854775804, 9223372036854775804);
    try test__negvdi2(-42, 42);
    try test__negvdi2(-7, 7);
    try test__negvdi2(-1, 1);
    try test__negvdi2(0, 0);
    try test__negvdi2(1, -1);
    try test__negvdi2(7, -7);
    try test__negvdi2(42, -42);
    try test__negvdi2(9223372036854775804, -9223372036854775804);
    try test__negvdi2(9223372036854775805, -9223372036854775805);
    try test__negvdi2(9223372036854775806, -9223372036854775806);
    try test__negvdi2(9223372036854775807, -9223372036854775807);
}

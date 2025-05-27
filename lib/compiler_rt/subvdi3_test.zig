const testing = @import("std").testing;

const __subvdi3 = @import("subvdi3.zig").__subvdi3;

fn test__subvdi3(a: i64, b: i64, expected: i64) !void {
    const result = __subvdi3(a, b);
    try testing.expectEqual(expected, result);
}

test "subvdi3" {
    // min i64 = -9223372036854775808
    // max i64 = 9223372036854775807
    // TODO write panic handler for testing panics
    // try test__subvdi3(-9223372036854775808, -1, -1); // panic
    // try test__addvdi3(9223372036854775807, 1, 1);  // panic
    try test__subvdi3(-9223372036854775807, 1, -9223372036854775808);
    try test__subvdi3(9223372036854775806, -1, 9223372036854775807);
}

const mulo = @import("mulo.zig");
const testing = @import("std").testing;

// ported from https://github.com/llvm-mirror/compiler-rt/tree/release_80/test/builtins/Unit

fn test__muloti4(a: i128, b: i128, expected: i128, expected_overflow: c_int) !void {
    var overflow: c_int = undefined;
    const x = mulo.__muloti4(a, b, &overflow);
    try testing.expect(overflow == expected_overflow and (expected_overflow != 0 or x == expected));
}

test "muloti4" {
    try test__muloti4(0, 0, 0, 0);
    try test__muloti4(0, 1, 0, 0);
    try test__muloti4(1, 0, 0, 0);
    try test__muloti4(0, 10, 0, 0);
    try test__muloti4(10, 0, 0, 0);
    try test__muloti4(0, 81985529216486895, 0, 0);
    try test__muloti4(81985529216486895, 0, 0, 0);

    try test__muloti4(0, -1, 0, 0);
    try test__muloti4(-1, 0, 0, 0);
    try test__muloti4(0, -10, 0, 0);
    try test__muloti4(-10, 0, 0, 0);
    try test__muloti4(0, -81985529216486895, 0, 0);
    try test__muloti4(-81985529216486895, 0, 0, 0);

    try test__muloti4(1, 1, 1, 0);
    try test__muloti4(1, 10, 10, 0);
    try test__muloti4(10, 1, 10, 0);
    try test__muloti4(1, 81985529216486895, 81985529216486895, 0);
    try test__muloti4(81985529216486895, 1, 81985529216486895, 0);

    try test__muloti4(1, -1, -1, 0);
    try test__muloti4(1, -10, -10, 0);
    try test__muloti4(-10, 1, -10, 0);
    try test__muloti4(1, -81985529216486895, -81985529216486895, 0);
    try test__muloti4(-81985529216486895, 1, -81985529216486895, 0);

    try test__muloti4(3037000499, 3037000499, 9223372030926249001, 0);
    try test__muloti4(-3037000499, 3037000499, -9223372030926249001, 0);
    try test__muloti4(3037000499, -3037000499, -9223372030926249001, 0);
    try test__muloti4(-3037000499, -3037000499, 9223372030926249001, 0);

    try test__muloti4(4398046511103, 2097152, 9223372036852678656, 0);
    try test__muloti4(-4398046511103, 2097152, -9223372036852678656, 0);
    try test__muloti4(4398046511103, -2097152, -9223372036852678656, 0);
    try test__muloti4(-4398046511103, -2097152, 9223372036852678656, 0);

    try test__muloti4(2097152, 4398046511103, 9223372036852678656, 0);
    try test__muloti4(-2097152, 4398046511103, -9223372036852678656, 0);
    try test__muloti4(2097152, -4398046511103, -9223372036852678656, 0);
    try test__muloti4(-2097152, -4398046511103, 9223372036852678656, 0);

    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x00000000000000B504F333F9DE5BE000))), @as(i128, @bitCast(@as(u128, 0x000000000000000000B504F333F9DE5B))), @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFF328DF915DA296E8A000))), 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), -2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 1);
    try test__muloti4(-2, @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 1);

    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), -1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 0);
    try test__muloti4(-1, @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 0, 0, 0);
    try test__muloti4(0, @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 0, 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 1, @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 0);
    try test__muloti4(1, @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 1);
    try test__muloti4(2, @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 1);

    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), -2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);
    try test__muloti4(-2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), -1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);
    try test__muloti4(-1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 0, 0, 0);
    try test__muloti4(0, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 0, 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 0);
    try test__muloti4(1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);
    try test__muloti4(2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);

    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), -2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 1);
    try test__muloti4(-2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 1);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), -1, @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 0);
    try test__muloti4(-1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), @as(i128, @bitCast(@as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))), 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 0, 0, 0);
    try test__muloti4(0, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 0, 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 0);
    try test__muloti4(1, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 0);
    try test__muloti4(@as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), 2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);
    try test__muloti4(2, @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000001))), @as(i128, @bitCast(@as(u128, 0x80000000000000000000000000000000))), 1);
}

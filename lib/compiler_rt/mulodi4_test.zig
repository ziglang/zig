const mulo = @import("mulo.zig");
const testing = @import("std").testing;

// ported from https://github.com/llvm-mirror/compiler-rt/tree/release_80/test/builtins/Unit

fn test__mulodi4(a: i64, b: i64, expected: i64, expected_overflow: c_int) !void {
    var overflow: c_int = undefined;
    const x = mulo.__mulodi4(a, b, &overflow);
    try testing.expect(overflow == expected_overflow and (expected_overflow != 0 or x == expected));
}

test "mulodi4" {
    try test__mulodi4(0, 0, 0, 0);
    try test__mulodi4(0, 1, 0, 0);
    try test__mulodi4(1, 0, 0, 0);
    try test__mulodi4(0, 10, 0, 0);
    try test__mulodi4(10, 0, 0, 0);
    try test__mulodi4(0, 81985529216486895, 0, 0);
    try test__mulodi4(81985529216486895, 0, 0, 0);

    try test__mulodi4(0, -1, 0, 0);
    try test__mulodi4(-1, 0, 0, 0);
    try test__mulodi4(0, -10, 0, 0);
    try test__mulodi4(-10, 0, 0, 0);
    try test__mulodi4(0, -81985529216486895, 0, 0);
    try test__mulodi4(-81985529216486895, 0, 0, 0);

    try test__mulodi4(1, 1, 1, 0);
    try test__mulodi4(1, 10, 10, 0);
    try test__mulodi4(10, 1, 10, 0);
    try test__mulodi4(1, 81985529216486895, 81985529216486895, 0);
    try test__mulodi4(81985529216486895, 1, 81985529216486895, 0);

    try test__mulodi4(1, -1, -1, 0);
    try test__mulodi4(1, -10, -10, 0);
    try test__mulodi4(-10, 1, -10, 0);
    try test__mulodi4(1, -81985529216486895, -81985529216486895, 0);
    try test__mulodi4(-81985529216486895, 1, -81985529216486895, 0);

    try test__mulodi4(3037000499, 3037000499, 9223372030926249001, 0);
    try test__mulodi4(-3037000499, 3037000499, -9223372030926249001, 0);
    try test__mulodi4(3037000499, -3037000499, -9223372030926249001, 0);
    try test__mulodi4(-3037000499, -3037000499, 9223372030926249001, 0);

    try test__mulodi4(4398046511103, 2097152, 9223372036852678656, 0);
    try test__mulodi4(-4398046511103, 2097152, -9223372036852678656, 0);
    try test__mulodi4(4398046511103, -2097152, -9223372036852678656, 0);
    try test__mulodi4(-4398046511103, -2097152, 9223372036852678656, 0);

    try test__mulodi4(2097152, 4398046511103, 9223372036852678656, 0);
    try test__mulodi4(-2097152, 4398046511103, -9223372036852678656, 0);
    try test__mulodi4(2097152, -4398046511103, -9223372036852678656, 0);
    try test__mulodi4(-2097152, -4398046511103, 9223372036852678656, 0);

    try test__mulodi4(0x7FFFFFFFFFFFFFFF, -2, 2, 1);
    try test__mulodi4(-2, 0x7FFFFFFFFFFFFFFF, 2, 1);
    try test__mulodi4(0x7FFFFFFFFFFFFFFF, -1, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 0);
    try test__mulodi4(-1, 0x7FFFFFFFFFFFFFFF, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 0);
    try test__mulodi4(0x7FFFFFFFFFFFFFFF, 0, 0, 0);
    try test__mulodi4(0, 0x7FFFFFFFFFFFFFFF, 0, 0);
    try test__mulodi4(0x7FFFFFFFFFFFFFFF, 1, 0x7FFFFFFFFFFFFFFF, 0);
    try test__mulodi4(1, 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF, 0);
    try test__mulodi4(0x7FFFFFFFFFFFFFFF, 2, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 1);
    try test__mulodi4(2, 0x7FFFFFFFFFFFFFFF, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 1);

    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000000))), -2, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);
    try test__mulodi4(-2, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000000))), -1, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);
    try test__mulodi4(-1, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000000))), 0, 0, 0);
    try test__mulodi4(0, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 0, 0);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 0);
    try test__mulodi4(1, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 0);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000000))), 2, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);
    try test__mulodi4(2, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);

    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000001))), -2, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 1);
    try test__mulodi4(-2, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 1);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000001))), -1, 0x7FFFFFFFFFFFFFFF, 0);
    try test__mulodi4(-1, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 0x7FFFFFFFFFFFFFFF, 0);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000001))), 0, 0, 0);
    try test__mulodi4(0, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 0, 0);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000001))), 1, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 0);
    try test__mulodi4(1, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), @as(i64, @bitCast(@as(u64, 0x8000000000000001))), 0);
    try test__mulodi4(@as(i64, @bitCast(@as(u64, 0x8000000000000001))), 2, @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);
    try test__mulodi4(2, @as(i64, @bitCast(@as(u64, 0x8000000000000001))), @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1);
}

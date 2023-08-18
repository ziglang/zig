const mulo = @import("mulo.zig");
const testing = @import("std").testing;

// ported from https://github.com/llvm-mirror/compiler-rt/tree/release_80/test/builtins/Unit

fn test__mulosi4(a: i32, b: i32, expected: i32, expected_overflow: c_int) !void {
    var overflow: c_int = undefined;
    const x = mulo.__mulosi4(a, b, &overflow);
    try testing.expect(overflow == expected_overflow and (expected_overflow != 0 or x == expected));
}

test "mulosi4" {
    try test__mulosi4(0, 0, 0, 0);
    try test__mulosi4(0, 1, 0, 0);
    try test__mulosi4(1, 0, 0, 0);
    try test__mulosi4(0, 10, 0, 0);
    try test__mulosi4(10, 0, 0, 0);
    try test__mulosi4(0, 0x1234567, 0, 0);
    try test__mulosi4(0x1234567, 0, 0, 0);

    try test__mulosi4(0, -1, 0, 0);
    try test__mulosi4(-1, 0, 0, 0);
    try test__mulosi4(0, -10, 0, 0);
    try test__mulosi4(-10, 0, 0, 0);
    try test__mulosi4(0, -0x1234567, 0, 0);
    try test__mulosi4(-0x1234567, 0, 0, 0);

    try test__mulosi4(1, 1, 1, 0);
    try test__mulosi4(1, 10, 10, 0);
    try test__mulosi4(10, 1, 10, 0);
    try test__mulosi4(1, 0x1234567, 0x1234567, 0);
    try test__mulosi4(0x1234567, 1, 0x1234567, 0);

    try test__mulosi4(1, -1, -1, 0);
    try test__mulosi4(1, -10, -10, 0);
    try test__mulosi4(-10, 1, -10, 0);
    try test__mulosi4(1, -0x1234567, -0x1234567, 0);
    try test__mulosi4(-0x1234567, 1, -0x1234567, 0);

    try test__mulosi4(0x7FFFFFFF, -2, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__mulosi4(-2, 0x7FFFFFFF, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__mulosi4(0x7FFFFFFF, -1, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__mulosi4(-1, 0x7FFFFFFF, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__mulosi4(0x7FFFFFFF, 0, 0, 0);
    try test__mulosi4(0, 0x7FFFFFFF, 0, 0);
    try test__mulosi4(0x7FFFFFFF, 1, 0x7FFFFFFF, 0);
    try test__mulosi4(1, 0x7FFFFFFF, 0x7FFFFFFF, 0);
    try test__mulosi4(0x7FFFFFFF, 2, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__mulosi4(2, 0x7FFFFFFF, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);

    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000000))), -2, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);
    try test__mulosi4(-2, @as(i32, @bitCast(@as(u32, 0x80000000))), @as(i32, @bitCast(@as(u32, 0x80000000))), 1);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000000))), -1, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);
    try test__mulosi4(-1, @as(i32, @bitCast(@as(u32, 0x80000000))), @as(i32, @bitCast(@as(u32, 0x80000000))), 1);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000000))), 0, 0, 0);
    try test__mulosi4(0, @as(i32, @bitCast(@as(u32, 0x80000000))), 0, 0);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000000))), 1, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);
    try test__mulosi4(1, @as(i32, @bitCast(@as(u32, 0x80000000))), @as(i32, @bitCast(@as(u32, 0x80000000))), 0);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000000))), 2, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);
    try test__mulosi4(2, @as(i32, @bitCast(@as(u32, 0x80000000))), @as(i32, @bitCast(@as(u32, 0x80000000))), 1);

    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000001))), -2, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__mulosi4(-2, @as(i32, @bitCast(@as(u32, 0x80000001))), @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000001))), -1, 0x7FFFFFFF, 0);
    try test__mulosi4(-1, @as(i32, @bitCast(@as(u32, 0x80000001))), 0x7FFFFFFF, 0);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000001))), 0, 0, 0);
    try test__mulosi4(0, @as(i32, @bitCast(@as(u32, 0x80000001))), 0, 0);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000001))), 1, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__mulosi4(1, @as(i32, @bitCast(@as(u32, 0x80000001))), @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__mulosi4(@as(i32, @bitCast(@as(u32, 0x80000001))), 2, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);
    try test__mulosi4(2, @as(i32, @bitCast(@as(u32, 0x80000001))), @as(i32, @bitCast(@as(u32, 0x80000000))), 1);
}

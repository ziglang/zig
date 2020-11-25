// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __muloti4 = @import("muloti4.zig").__muloti4;
const testing = @import("std").testing;

fn test__muloti4(a: i128, b: i128, expected: i128, expected_overflow: c_int) void {
    var overflow: c_int = undefined;
    const x = __muloti4(a, b, &overflow);
    testing.expect(overflow == expected_overflow and (expected_overflow != 0 or x == expected));
}

test "muloti4" {
    test__muloti4(0, 0, 0, 0);
    test__muloti4(0, 1, 0, 0);
    test__muloti4(1, 0, 0, 0);
    test__muloti4(0, 10, 0, 0);
    test__muloti4(10, 0, 0, 0);

    test__muloti4(0, 81985529216486895, 0, 0);
    test__muloti4(81985529216486895, 0, 0, 0);

    test__muloti4(0, -1, 0, 0);
    test__muloti4(-1, 0, 0, 0);
    test__muloti4(0, -10, 0, 0);
    test__muloti4(-10, 0, 0, 0);
    test__muloti4(0, -81985529216486895, 0, 0);
    test__muloti4(-81985529216486895, 0, 0, 0);

    test__muloti4(3037000499, 3037000499, 9223372030926249001, 0);
    test__muloti4(-3037000499, 3037000499, -9223372030926249001, 0);
    test__muloti4(3037000499, -3037000499, -9223372030926249001, 0);
    test__muloti4(-3037000499, -3037000499, 9223372030926249001, 0);

    test__muloti4(4398046511103, 2097152, 9223372036852678656, 0);
    test__muloti4(-4398046511103, 2097152, -9223372036852678656, 0);
    test__muloti4(4398046511103, -2097152, -9223372036852678656, 0);
    test__muloti4(-4398046511103, -2097152, 9223372036852678656, 0);

    test__muloti4(2097152, 4398046511103, 9223372036852678656, 0);
    test__muloti4(-2097152, 4398046511103, -9223372036852678656, 0);
    test__muloti4(2097152, -4398046511103, -9223372036852678656, 0);
    test__muloti4(-2097152, -4398046511103, 9223372036852678656, 0);

    test__muloti4(@bitCast(i128, @as(u128, 0x00000000000000B504F333F9DE5BE000)), @bitCast(i128, @as(u128, 0x000000000000000000B504F333F9DE5B)), @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFF328DF915DA296E8A000)), 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), -2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 1);
    test__muloti4(-2, @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 1);

    test__muloti4(@bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), -1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 0);
    test__muloti4(-1, @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 0, 0, 0);
    test__muloti4(0, @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 0, 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 1, @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 0);
    test__muloti4(1, @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 1);
    test__muloti4(2, @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 1);

    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), -2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);
    test__muloti4(-2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), -1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);
    test__muloti4(-1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 0, 0, 0);
    test__muloti4(0, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 0, 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 0);
    test__muloti4(1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);
    test__muloti4(2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);

    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), -2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 1);
    test__muloti4(-2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 1);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), -1, @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 0);
    test__muloti4(-1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), @bitCast(i128, @as(u128, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)), 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 0, 0, 0);
    test__muloti4(0, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 0, 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 0);
    test__muloti4(1, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 0);
    test__muloti4(@bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), 2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);
    test__muloti4(2, @bitCast(i128, @as(u128, 0x80000000000000000000000000000001)), @bitCast(i128, @as(u128, 0x80000000000000000000000000000000)), 1);
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __mulodi4 = @import("mulodi4.zig").__mulodi4;
const testing = @import("std").testing;

fn test__mulodi4(a: i64, b: i64, expected: i64, expected_overflow: c_int) void {
    var overflow: c_int = undefined;
    const x = __mulodi4(a, b, &overflow);
    testing.expect(overflow == expected_overflow and (expected_overflow != 0 or x == expected));
}

test "mulodi4" {
    test__mulodi4(0, 0, 0, 0);
    test__mulodi4(0, 1, 0, 0);
    test__mulodi4(1, 0, 0, 0);
    test__mulodi4(0, 10, 0, 0);
    test__mulodi4(10, 0, 0, 0);
    test__mulodi4(0, 81985529216486895, 0, 0);
    test__mulodi4(81985529216486895, 0, 0, 0);

    test__mulodi4(0, -1, 0, 0);
    test__mulodi4(-1, 0, 0, 0);
    test__mulodi4(0, -10, 0, 0);
    test__mulodi4(-10, 0, 0, 0);
    test__mulodi4(0, -81985529216486895, 0, 0);
    test__mulodi4(-81985529216486895, 0, 0, 0);

    test__mulodi4(1, 1, 1, 0);
    test__mulodi4(1, 10, 10, 0);
    test__mulodi4(10, 1, 10, 0);
    test__mulodi4(1, 81985529216486895, 81985529216486895, 0);
    test__mulodi4(81985529216486895, 1, 81985529216486895, 0);

    test__mulodi4(1, -1, -1, 0);
    test__mulodi4(1, -10, -10, 0);
    test__mulodi4(-10, 1, -10, 0);
    test__mulodi4(1, -81985529216486895, -81985529216486895, 0);
    test__mulodi4(-81985529216486895, 1, -81985529216486895, 0);

    test__mulodi4(3037000499, 3037000499, 9223372030926249001, 0);
    test__mulodi4(-3037000499, 3037000499, -9223372030926249001, 0);
    test__mulodi4(3037000499, -3037000499, -9223372030926249001, 0);
    test__mulodi4(-3037000499, -3037000499, 9223372030926249001, 0);

    test__mulodi4(4398046511103, 2097152, 9223372036852678656, 0);
    test__mulodi4(-4398046511103, 2097152, -9223372036852678656, 0);
    test__mulodi4(4398046511103, -2097152, -9223372036852678656, 0);
    test__mulodi4(-4398046511103, -2097152, 9223372036852678656, 0);

    test__mulodi4(2097152, 4398046511103, 9223372036852678656, 0);
    test__mulodi4(-2097152, 4398046511103, -9223372036852678656, 0);
    test__mulodi4(2097152, -4398046511103, -9223372036852678656, 0);
    test__mulodi4(-2097152, -4398046511103, 9223372036852678656, 0);

    test__mulodi4(0x7FFFFFFFFFFFFFFF, -2, 2, 1);
    test__mulodi4(-2, 0x7FFFFFFFFFFFFFFF, 2, 1);
    test__mulodi4(0x7FFFFFFFFFFFFFFF, -1, @bitCast(i64, @as(u64, 0x8000000000000001)), 0);
    test__mulodi4(-1, 0x7FFFFFFFFFFFFFFF, @bitCast(i64, @as(u64, 0x8000000000000001)), 0);
    test__mulodi4(0x7FFFFFFFFFFFFFFF, 0, 0, 0);
    test__mulodi4(0, 0x7FFFFFFFFFFFFFFF, 0, 0);
    test__mulodi4(0x7FFFFFFFFFFFFFFF, 1, 0x7FFFFFFFFFFFFFFF, 0);
    test__mulodi4(1, 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF, 0);
    test__mulodi4(0x7FFFFFFFFFFFFFFF, 2, @bitCast(i64, @as(u64, 0x8000000000000001)), 1);
    test__mulodi4(2, 0x7FFFFFFFFFFFFFFF, @bitCast(i64, @as(u64, 0x8000000000000001)), 1);

    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000000)), -2, @bitCast(i64, @as(u64, 0x8000000000000000)), 1);
    test__mulodi4(-2, @bitCast(i64, @as(u64, 0x8000000000000000)), @bitCast(i64, @as(u64, 0x8000000000000000)), 1);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000000)), -1, @bitCast(i64, @as(u64, 0x8000000000000000)), 1);
    test__mulodi4(-1, @bitCast(i64, @as(u64, 0x8000000000000000)), @bitCast(i64, @as(u64, 0x8000000000000000)), 1);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000000)), 0, 0, 0);
    test__mulodi4(0, @bitCast(i64, @as(u64, 0x8000000000000000)), 0, 0);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000000)), 1, @bitCast(i64, @as(u64, 0x8000000000000000)), 0);
    test__mulodi4(1, @bitCast(i64, @as(u64, 0x8000000000000000)), @bitCast(i64, @as(u64, 0x8000000000000000)), 0);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000000)), 2, @bitCast(i64, @as(u64, 0x8000000000000000)), 1);
    test__mulodi4(2, @bitCast(i64, @as(u64, 0x8000000000000000)), @bitCast(i64, @as(u64, 0x8000000000000000)), 1);

    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000001)), -2, @bitCast(i64, @as(u64, 0x8000000000000001)), 1);
    test__mulodi4(-2, @bitCast(i64, @as(u64, 0x8000000000000001)), @bitCast(i64, @as(u64, 0x8000000000000001)), 1);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000001)), -1, 0x7FFFFFFFFFFFFFFF, 0);
    test__mulodi4(-1, @bitCast(i64, @as(u64, 0x8000000000000001)), 0x7FFFFFFFFFFFFFFF, 0);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000001)), 0, 0, 0);
    test__mulodi4(0, @bitCast(i64, @as(u64, 0x8000000000000001)), 0, 0);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000001)), 1, @bitCast(i64, @as(u64, 0x8000000000000001)), 0);
    test__mulodi4(1, @bitCast(i64, @as(u64, 0x8000000000000001)), @bitCast(i64, @as(u64, 0x8000000000000001)), 0);
    test__mulodi4(@bitCast(i64, @as(u64, 0x8000000000000001)), 2, @bitCast(i64, @as(u64, 0x8000000000000000)), 1);
    test__mulodi4(2, @bitCast(i64, @as(u64, 0x8000000000000001)), @bitCast(i64, @as(u64, 0x8000000000000000)), 1);
}

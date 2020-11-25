// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __muldi3 = @import("muldi3.zig").__muldi3;
const testing = @import("std").testing;

fn test__muldi3(a: i64, b: i64, expected: i64) void {
    const x = __muldi3(a, b);
    testing.expect(x == expected);
}

test "muldi3" {
    test__muldi3(0, 0, 0);
    test__muldi3(0, 1, 0);
    test__muldi3(1, 0, 0);
    test__muldi3(0, 10, 0);
    test__muldi3(10, 0, 0);
    test__muldi3(0, 81985529216486895, 0);
    test__muldi3(81985529216486895, 0, 0);

    test__muldi3(0, -1, 0);
    test__muldi3(-1, 0, 0);
    test__muldi3(0, -10, 0);
    test__muldi3(-10, 0, 0);
    test__muldi3(0, -81985529216486895, 0);
    test__muldi3(-81985529216486895, 0, 0);

    test__muldi3(1, 1, 1);
    test__muldi3(1, 10, 10);
    test__muldi3(10, 1, 10);
    test__muldi3(1, 81985529216486895, 81985529216486895);
    test__muldi3(81985529216486895, 1, 81985529216486895);

    test__muldi3(1, -1, -1);
    test__muldi3(1, -10, -10);
    test__muldi3(-10, 1, -10);
    test__muldi3(1, -81985529216486895, -81985529216486895);
    test__muldi3(-81985529216486895, 1, -81985529216486895);

    test__muldi3(3037000499, 3037000499, 9223372030926249001);
    test__muldi3(-3037000499, 3037000499, -9223372030926249001);
    test__muldi3(3037000499, -3037000499, -9223372030926249001);
    test__muldi3(-3037000499, -3037000499, 9223372030926249001);

    test__muldi3(4398046511103, 2097152, 9223372036852678656);
    test__muldi3(-4398046511103, 2097152, -9223372036852678656);
    test__muldi3(4398046511103, -2097152, -9223372036852678656);
    test__muldi3(-4398046511103, -2097152, 9223372036852678656);

    test__muldi3(2097152, 4398046511103, 9223372036852678656);
    test__muldi3(-2097152, 4398046511103, -9223372036852678656);
    test__muldi3(2097152, -4398046511103, -9223372036852678656);
    test__muldi3(-2097152, -4398046511103, 9223372036852678656);
}

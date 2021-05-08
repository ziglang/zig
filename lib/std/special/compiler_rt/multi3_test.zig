// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __multi3 = @import("multi3.zig").__multi3;
const testing = @import("std").testing;

fn test__multi3(a: i128, b: i128, expected: i128) !void {
    const x = __multi3(a, b);
    try testing.expect(x == expected);
}

test "multi3" {
    try test__multi3(0, 0, 0);
    try test__multi3(0, 1, 0);
    try test__multi3(1, 0, 0);
    try test__multi3(0, 10, 0);
    try test__multi3(10, 0, 0);
    try test__multi3(0, 81985529216486895, 0);
    try test__multi3(81985529216486895, 0, 0);

    try test__multi3(0, -1, 0);
    try test__multi3(-1, 0, 0);
    try test__multi3(0, -10, 0);
    try test__multi3(-10, 0, 0);
    try test__multi3(0, -81985529216486895, 0);
    try test__multi3(-81985529216486895, 0, 0);

    try test__multi3(1, 1, 1);
    try test__multi3(1, 10, 10);
    try test__multi3(10, 1, 10);
    try test__multi3(1, 81985529216486895, 81985529216486895);
    try test__multi3(81985529216486895, 1, 81985529216486895);

    try test__multi3(1, -1, -1);
    try test__multi3(1, -10, -10);
    try test__multi3(-10, 1, -10);
    try test__multi3(1, -81985529216486895, -81985529216486895);
    try test__multi3(-81985529216486895, 1, -81985529216486895);

    try test__multi3(3037000499, 3037000499, 9223372030926249001);
    try test__multi3(-3037000499, 3037000499, -9223372030926249001);
    try test__multi3(3037000499, -3037000499, -9223372030926249001);
    try test__multi3(-3037000499, -3037000499, 9223372030926249001);

    try test__multi3(4398046511103, 2097152, 9223372036852678656);
    try test__multi3(-4398046511103, 2097152, -9223372036852678656);
    try test__multi3(4398046511103, -2097152, -9223372036852678656);
    try test__multi3(-4398046511103, -2097152, 9223372036852678656);

    try test__multi3(2097152, 4398046511103, 9223372036852678656);
    try test__multi3(-2097152, 4398046511103, -9223372036852678656);
    try test__multi3(2097152, -4398046511103, -9223372036852678656);
    try test__multi3(-2097152, -4398046511103, 9223372036852678656);

    try test__multi3(0x00000000000000B504F333F9DE5BE000, 0x000000000000000000B504F333F9DE5B, 0x7FFFFFFFFFFFF328DF915DA296E8A000);
}

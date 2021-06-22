// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __floatditf = @import("floatditf.zig").__floatditf;
const testing = @import("std").testing;

fn test__floatditf(a: i64, expected: f128) !void {
    const x = __floatditf(a);
    try testing.expect(x == expected);
}

test "floatditf" {
    try test__floatditf(0x7fffffffffffffff, make_ti(0x403dffffffffffff, 0xfffc000000000000));
    try test__floatditf(0x123456789abcdef1, make_ti(0x403b23456789abcd, 0xef10000000000000));
    try test__floatditf(0x2, make_ti(0x4000000000000000, 0x0));
    try test__floatditf(0x1, make_ti(0x3fff000000000000, 0x0));
    try test__floatditf(0x0, make_ti(0x0, 0x0));
    try test__floatditf(@bitCast(i64, @as(u64, 0xffffffffffffffff)), make_ti(0xbfff000000000000, 0x0));
    try test__floatditf(@bitCast(i64, @as(u64, 0xfffffffffffffffe)), make_ti(0xc000000000000000, 0x0));
    try test__floatditf(-0x123456789abcdef1, make_ti(0xc03b23456789abcd, 0xef10000000000000));
    try test__floatditf(@bitCast(i64, @as(u64, 0x8000000000000000)), make_ti(0xc03e000000000000, 0x0));
}

fn make_ti(high: u64, low: u64) f128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return @bitCast(f128, result);
}

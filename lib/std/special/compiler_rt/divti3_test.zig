// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __divti3 = @import("divti3.zig").__divti3;
const testing = @import("std").testing;

fn test__divti3(a: i128, b: i128, expected: i128) !void {
    const x = __divti3(a, b);
    try testing.expect(x == expected);
}

test "divti3" {
    try test__divti3(0, 1, 0);
    try test__divti3(0, -1, 0);
    try test__divti3(2, 1, 2);
    try test__divti3(2, -1, -2);
    try test__divti3(-2, 1, -2);
    try test__divti3(-2, -1, 2);

    try test__divti3(@bitCast(i128, @as(u128, 0x8 << 124)), 1, @bitCast(i128, @as(u128, 0x8 << 124)));
    try test__divti3(@bitCast(i128, @as(u128, 0x8 << 124)), -1, @bitCast(i128, @as(u128, 0x8 << 124)));
    try test__divti3(@bitCast(i128, @as(u128, 0x8 << 124)), -2, @bitCast(i128, @as(u128, 0x4 << 124)));
    try test__divti3(@bitCast(i128, @as(u128, 0x8 << 124)), 2, @bitCast(i128, @as(u128, 0xc << 124)));
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixunstfsi = @import("fixunstfsi.zig").__fixunstfsi;
const testing = @import("std").testing;

fn test__fixunstfsi(a: f128, expected: u32) !void {
    const x = __fixunstfsi(a);
    try testing.expect(x == expected);
}

const inf128 = @bitCast(f128, @as(u128, 0x7fff0000000000000000000000000000));

test "fixunstfsi" {
    try test__fixunstfsi(inf128, 0xffffffff);
    try test__fixunstfsi(0, 0x0);
    try test__fixunstfsi(0x1.23456789abcdefp+5, 0x24);
    try test__fixunstfsi(0x1.23456789abcdefp-3, 0x0);
    try test__fixunstfsi(0x1.23456789abcdefp+20, 0x123456);
    try test__fixunstfsi(0x1.23456789abcdefp+40, 0xffffffff);
    try test__fixunstfsi(0x1.23456789abcdefp+256, 0xffffffff);
    try test__fixunstfsi(-0x1.23456789abcdefp+3, 0x0);

    try test__fixunstfsi(0x1.p+32, 0xFFFFFFFF);
}

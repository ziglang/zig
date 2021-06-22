// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __ashlti3 = @import("shift.zig").__ashlti3;
const testing = @import("std").testing;

fn test__ashlti3(a: i128, b: i32, expected: i128) !void {
    const x = __ashlti3(a, b);
    try testing.expectEqual(expected, x);
}

test "ashlti3" {
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 0, @bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 1, @bitCast(i128, @intCast(u128, 0xFDB97530ECA8642BFDB97530ECA8642A)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 2, @bitCast(i128, @intCast(u128, 0xFB72EA61D950C857FB72EA61D950C854)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 3, @bitCast(i128, @intCast(u128, 0xF6E5D4C3B2A190AFF6E5D4C3B2A190A8)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 4, @bitCast(i128, @intCast(u128, 0xEDCBA9876543215FEDCBA98765432150)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 28, @bitCast(i128, @intCast(u128, 0x876543215FEDCBA98765432150000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 29, @bitCast(i128, @intCast(u128, 0x0ECA8642BFDB97530ECA8642A0000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 30, @bitCast(i128, @intCast(u128, 0x1D950C857FB72EA61D950C8540000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 31, @bitCast(i128, @intCast(u128, 0x3B2A190AFF6E5D4C3B2A190A80000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 32, @bitCast(i128, @intCast(u128, 0x76543215FEDCBA987654321500000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 33, @bitCast(i128, @intCast(u128, 0xECA8642BFDB97530ECA8642A00000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 34, @bitCast(i128, @intCast(u128, 0xD950C857FB72EA61D950C85400000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 35, @bitCast(i128, @intCast(u128, 0xB2A190AFF6E5D4C3B2A190A800000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 36, @bitCast(i128, @intCast(u128, 0x6543215FEDCBA9876543215000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 60, @bitCast(i128, @intCast(u128, 0x5FEDCBA9876543215000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 61, @bitCast(i128, @intCast(u128, 0xBFDB97530ECA8642A000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 62, @bitCast(i128, @intCast(u128, 0x7FB72EA61D950C854000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 63, @bitCast(i128, @intCast(u128, 0xFF6E5D4C3B2A190A8000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 64, @bitCast(i128, @intCast(u128, 0xFEDCBA98765432150000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 65, @bitCast(i128, @intCast(u128, 0xFDB97530ECA8642A0000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 66, @bitCast(i128, @intCast(u128, 0xFB72EA61D950C8540000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 67, @bitCast(i128, @intCast(u128, 0xF6E5D4C3B2A190A80000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 68, @bitCast(i128, @intCast(u128, 0xEDCBA987654321500000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 92, @bitCast(i128, @intCast(u128, 0x87654321500000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 93, @bitCast(i128, @intCast(u128, 0x0ECA8642A00000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 94, @bitCast(i128, @intCast(u128, 0x1D950C85400000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 95, @bitCast(i128, @intCast(u128, 0x3B2A190A800000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 96, @bitCast(i128, @intCast(u128, 0x76543215000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 97, @bitCast(i128, @intCast(u128, 0xECA8642A000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 98, @bitCast(i128, @intCast(u128, 0xD950C854000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 99, @bitCast(i128, @intCast(u128, 0xB2A190A8000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 100, @bitCast(i128, @intCast(u128, 0x65432150000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 124, @bitCast(i128, @intCast(u128, 0x50000000000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 125, @bitCast(i128, @intCast(u128, 0xA0000000000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 126, @bitCast(i128, @intCast(u128, 0x40000000000000000000000000000000)));
    try test__ashlti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 127, @bitCast(i128, @intCast(u128, 0x80000000000000000000000000000000)));
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __ashldi3 = @import("shift.zig").__ashldi3;
const testing = @import("std").testing;

fn test__ashldi3(a: i64, b: i32, expected: u64) void {
    const x = __ashldi3(a, b);
    testing.expectEqual(@bitCast(i64, expected), x);
}

test "ashldi3" {
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 0, 0x123456789ABCDEF);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 1, 0x2468ACF13579BDE);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 2, 0x48D159E26AF37BC);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 3, 0x91A2B3C4D5E6F78);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 4, 0x123456789ABCDEF0);

    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 28, 0x789ABCDEF0000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 29, 0xF13579BDE0000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 30, 0xE26AF37BC0000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 31, 0xC4D5E6F780000000);

    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 32, 0x89ABCDEF00000000);

    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 33, 0x13579BDE00000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 34, 0x26AF37BC00000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 35, 0x4D5E6F7800000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 36, 0x9ABCDEF000000000);

    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 60, 0xF000000000000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 61, 0xE000000000000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 62, 0xC000000000000000);
    test__ashldi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 63, 0x8000000000000000);
}

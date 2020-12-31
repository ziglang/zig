// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __lshrdi3 = @import("shift.zig").__lshrdi3;
const testing = @import("std").testing;

fn test__lshrdi3(a: i64, b: i32, expected: u64) void {
    const x = __lshrdi3(a, b);
    testing.expectEqual(@bitCast(i64, expected), x);
}

test "lshrdi3" {
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 0, 0x123456789ABCDEF);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 1, 0x91A2B3C4D5E6F7);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 2, 0x48D159E26AF37B);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 3, 0x2468ACF13579BD);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 4, 0x123456789ABCDE);

    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 28, 0x12345678);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 29, 0x91A2B3C);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 30, 0x48D159E);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 31, 0x2468ACF);

    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 32, 0x1234567);

    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 33, 0x91A2B3);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 34, 0x48D159);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 35, 0x2468AC);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 36, 0x123456);

    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 60, 0);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 61, 0);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 62, 0);
    test__lshrdi3(@bitCast(i64, @as(u64, 0x0123456789ABCDEF)), 63, 0);

    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 0, 0xFEDCBA9876543210);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 1, 0x7F6E5D4C3B2A1908);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 2, 0x3FB72EA61D950C84);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 3, 0x1FDB97530ECA8642);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 4, 0xFEDCBA987654321);

    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 28, 0xFEDCBA987);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 29, 0x7F6E5D4C3);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 30, 0x3FB72EA61);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 31, 0x1FDB97530);

    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 32, 0xFEDCBA98);

    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 33, 0x7F6E5D4C);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 34, 0x3FB72EA6);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 35, 0x1FDB9753);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xFEDCBA9876543210)), 36, 0xFEDCBA9);

    test__lshrdi3(@bitCast(i64, @as(u64, 0xAEDCBA9876543210)), 60, 0xA);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xAEDCBA9876543210)), 61, 0x5);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xAEDCBA9876543210)), 62, 0x2);
    test__lshrdi3(@bitCast(i64, @as(u64, 0xAEDCBA9876543210)), 63, 0x1);
}

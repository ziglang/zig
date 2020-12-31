// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __lshrti3 = @import("shift.zig").__lshrti3;
const testing = @import("std").testing;

fn test__lshrti3(a: i128, b: i32, expected: i128) void {
    const x = __lshrti3(a, b);
    testing.expectEqual(expected, x);
}

test "lshrti3" {
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 0, @bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 1, @bitCast(i128, @intCast(u128, 0x7F6E5D4C3B2A190AFF6E5D4C3B2A190A)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 2, @bitCast(i128, @intCast(u128, 0x3FB72EA61D950C857FB72EA61D950C85)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 3, @bitCast(i128, @intCast(u128, 0x1FDB97530ECA8642BFDB97530ECA8642)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 4, @bitCast(i128, @intCast(u128, 0x0FEDCBA9876543215FEDCBA987654321)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 28, @bitCast(i128, @intCast(u128, 0x0000000FEDCBA9876543215FEDCBA987)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 29, @bitCast(i128, @intCast(u128, 0x00000007F6E5D4C3B2A190AFF6E5D4C3)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 30, @bitCast(i128, @intCast(u128, 0x00000003FB72EA61D950C857FB72EA61)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 31, @bitCast(i128, @intCast(u128, 0x00000001FDB97530ECA8642BFDB97530)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 32, @bitCast(i128, @intCast(u128, 0x00000000FEDCBA9876543215FEDCBA98)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 33, @bitCast(i128, @intCast(u128, 0x000000007F6E5D4C3B2A190AFF6E5D4C)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 34, @bitCast(i128, @intCast(u128, 0x000000003FB72EA61D950C857FB72EA6)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 35, @bitCast(i128, @intCast(u128, 0x000000001FDB97530ECA8642BFDB9753)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 36, @bitCast(i128, @intCast(u128, 0x000000000FEDCBA9876543215FEDCBA9)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 60, @bitCast(i128, @intCast(u128, 0x000000000000000FEDCBA9876543215F)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 61, @bitCast(i128, @intCast(u128, 0x0000000000000007F6E5D4C3B2A190AF)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 62, @bitCast(i128, @intCast(u128, 0x0000000000000003FB72EA61D950C857)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 63, @bitCast(i128, @intCast(u128, 0x0000000000000001FDB97530ECA8642B)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 64, @bitCast(i128, @intCast(u128, 0x0000000000000000FEDCBA9876543215)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 65, @bitCast(i128, @intCast(u128, 0x00000000000000007F6E5D4C3B2A190A)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 66, @bitCast(i128, @intCast(u128, 0x00000000000000003FB72EA61D950C85)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 67, @bitCast(i128, @intCast(u128, 0x00000000000000001FDB97530ECA8642)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 68, @bitCast(i128, @intCast(u128, 0x00000000000000000FEDCBA987654321)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 92, @bitCast(i128, @intCast(u128, 0x00000000000000000000000FEDCBA987)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 93, @bitCast(i128, @intCast(u128, 0x000000000000000000000007F6E5D4C3)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 94, @bitCast(i128, @intCast(u128, 0x000000000000000000000003FB72EA61)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 95, @bitCast(i128, @intCast(u128, 0x000000000000000000000001FDB97530)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 96, @bitCast(i128, @intCast(u128, 0x000000000000000000000000FEDCBA98)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 97, @bitCast(i128, @intCast(u128, 0x0000000000000000000000007F6E5D4C)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 98, @bitCast(i128, @intCast(u128, 0x0000000000000000000000003FB72EA6)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 99, @bitCast(i128, @intCast(u128, 0x0000000000000000000000001FDB9753)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 100, @bitCast(i128, @intCast(u128, 0x0000000000000000000000000FEDCBA9)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 124, @bitCast(i128, @intCast(u128, 0x0000000000000000000000000000000F)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 125, @bitCast(i128, @intCast(u128, 0x00000000000000000000000000000007)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 126, @bitCast(i128, @intCast(u128, 0x00000000000000000000000000000003)));
    test__lshrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 127, @bitCast(i128, @intCast(u128, 0x00000000000000000000000000000001)));
}

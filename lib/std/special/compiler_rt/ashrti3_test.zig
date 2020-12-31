// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __ashrti3 = @import("shift.zig").__ashrti3;
const testing = @import("std").testing;

fn test__ashrti3(a: i128, b: i32, expected: i128) void {
    const x = __ashrti3(a, b);
    testing.expectEqual(expected, x);
}

test "ashrti3" {
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 0, @bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 1, @bitCast(i128, @intCast(u128, 0xFF6E5D4C3B2A190AFF6E5D4C3B2A190A)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 2, @bitCast(i128, @intCast(u128, 0xFFB72EA61D950C857FB72EA61D950C85)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 3, @bitCast(i128, @intCast(u128, 0xFFDB97530ECA8642BFDB97530ECA8642)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 4, @bitCast(i128, @intCast(u128, 0xFFEDCBA9876543215FEDCBA987654321)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 28, @bitCast(i128, @intCast(u128, 0xFFFFFFFFEDCBA9876543215FEDCBA987)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 29, @bitCast(i128, @intCast(u128, 0xFFFFFFFFF6E5D4C3B2A190AFF6E5D4C3)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 30, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFB72EA61D950C857FB72EA61)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 31, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFDB97530ECA8642BFDB97530)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 32, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFEDCBA9876543215FEDCBA98)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 33, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFF6E5D4C3B2A190AFF6E5D4C)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 34, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFB72EA61D950C857FB72EA6)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 35, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFDB97530ECA8642BFDB9753)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 36, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFEDCBA9876543215FEDCBA9)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 60, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFEDCBA9876543215F)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 61, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFF6E5D4C3B2A190AF)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 62, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFB72EA61D950C857)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 63, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFDB97530ECA8642B)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 64, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFEDCBA9876543215)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 65, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFF6E5D4C3B2A190A)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 66, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFB72EA61D950C85)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 67, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFDB97530ECA8642)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 68, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFEDCBA987654321)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 92, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFEDCBA987)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 93, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFF6E5D4C3)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 94, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFB72EA61)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 95, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFDB97530)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 96, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFEDCBA98)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 97, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFF6E5D4C)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 98, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFB72EA6)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 99, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFDB9753)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 100, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFEDCBA9)));

    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 124, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 125, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 126, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)));
    test__ashrti3(@bitCast(i128, @intCast(u128, 0xFEDCBA9876543215FEDCBA9876543215)), 127, @bitCast(i128, @intCast(u128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)));
}

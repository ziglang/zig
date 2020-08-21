// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixunstfti = @import("fixunstfti.zig").__fixunstfti;
const testing = @import("std").testing;

fn test__fixunstfti(a: f128, expected: u128) void {
    const x = __fixunstfti(a);
    testing.expect(x == expected);
}

const inf128 = @bitCast(f128, @as(u128, 0x7fff0000000000000000000000000000));

test "fixunstfti" {
    test__fixunstfti(inf128, 0xffffffffffffffffffffffffffffffff);

    test__fixunstfti(0.0, 0);

    test__fixunstfti(0.5, 0);
    test__fixunstfti(0.99, 0);
    test__fixunstfti(1.0, 1);
    test__fixunstfti(1.5, 1);
    test__fixunstfti(1.99, 1);
    test__fixunstfti(2.0, 2);
    test__fixunstfti(2.01, 2);
    test__fixunstfti(-0.01, 0);
    test__fixunstfti(-0.99, 0);

    test__fixunstfti(0x1.p+128, 0xffffffffffffffffffffffffffffffff);

    test__fixunstfti(0x1.FFFFFEp+126, 0x7fffff80000000000000000000000000);
    test__fixunstfti(0x1.FFFFFEp+127, 0xffffff00000000000000000000000000);
    test__fixunstfti(0x1.FFFFFEp+128, 0xffffffffffffffffffffffffffffffff);
    test__fixunstfti(0x1.FFFFFEp+129, 0xffffffffffffffffffffffffffffffff);
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixunstfdi = @import("fixunstfdi.zig").__fixunstfdi;
const testing = @import("std").testing;

fn test__fixunstfdi(a: f128, expected: u64) void {
    const x = __fixunstfdi(a);
    testing.expect(x == expected);
}

test "fixunstfdi" {
    test__fixunstfdi(0.0, 0);

    test__fixunstfdi(0.5, 0);
    test__fixunstfdi(0.99, 0);
    test__fixunstfdi(1.0, 1);
    test__fixunstfdi(1.5, 1);
    test__fixunstfdi(1.99, 1);
    test__fixunstfdi(2.0, 2);
    test__fixunstfdi(2.01, 2);
    test__fixunstfdi(-0.5, 0);
    test__fixunstfdi(-0.99, 0);
    test__fixunstfdi(-1.0, 0);
    test__fixunstfdi(-1.5, 0);
    test__fixunstfdi(-1.99, 0);
    test__fixunstfdi(-2.0, 0);
    test__fixunstfdi(-2.01, 0);

    test__fixunstfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    test__fixunstfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    test__fixunstfdi(-0x1.FFFFFEp+62, 0);
    test__fixunstfdi(-0x1.FFFFFCp+62, 0);

    test__fixunstfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    test__fixunstfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);

    test__fixunstfdi(-0x1.FFFFFFFFFFFFFp+62, 0);
    test__fixunstfdi(-0x1.FFFFFFFFFFFFEp+62, 0);

    test__fixunstfdi(0x1.FFFFFFFFFFFFFFFEp+63, 0xFFFFFFFFFFFFFFFF);
    test__fixunstfdi(0x1.0000000000000002p+63, 0x8000000000000001);
    test__fixunstfdi(0x1.0000000000000000p+63, 0x8000000000000000);
    test__fixunstfdi(0x1.FFFFFFFFFFFFFFFCp+62, 0x7FFFFFFFFFFFFFFF);
    test__fixunstfdi(0x1.FFFFFFFFFFFFFFF8p+62, 0x7FFFFFFFFFFFFFFE);
    test__fixunstfdi(0x1.p+64, 0xFFFFFFFFFFFFFFFF);

    test__fixunstfdi(-0x1.0000000000000000p+63, 0);
    test__fixunstfdi(-0x1.FFFFFFFFFFFFFFFCp+62, 0);
    test__fixunstfdi(-0x1.FFFFFFFFFFFFFFF8p+62, 0);
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixunssfti = @import("fixunssfti.zig").__fixunssfti;
const testing = @import("std").testing;

fn test__fixunssfti(a: f32, expected: u128) void {
    const x = __fixunssfti(a);
    testing.expect(x == expected);
}

test "fixunssfti" {
    test__fixunssfti(0.0, 0);

    test__fixunssfti(0.5, 0);
    test__fixunssfti(0.99, 0);
    test__fixunssfti(1.0, 1);
    test__fixunssfti(1.5, 1);
    test__fixunssfti(1.99, 1);
    test__fixunssfti(2.0, 2);
    test__fixunssfti(2.01, 2);
    test__fixunssfti(-0.5, 0);
    test__fixunssfti(-0.99, 0);

    test__fixunssfti(-1.0, 0);
    test__fixunssfti(-1.5, 0);
    test__fixunssfti(-1.99, 0);
    test__fixunssfti(-2.0, 0);
    test__fixunssfti(-2.01, 0);

    test__fixunssfti(0x1.FFFFFEp+63, 0xFFFFFF0000000000);
    test__fixunssfti(0x1.000000p+63, 0x8000000000000000);
    test__fixunssfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    test__fixunssfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    test__fixunssfti(0x1.FFFFFEp+127, 0xFFFFFF00000000000000000000000000);
    test__fixunssfti(0x1.000000p+127, 0x80000000000000000000000000000000);
    test__fixunssfti(0x1.FFFFFEp+126, 0x7FFFFF80000000000000000000000000);
    test__fixunssfti(0x1.FFFFFCp+126, 0x7FFFFF00000000000000000000000000);

    test__fixunssfti(-0x1.FFFFFEp+62, 0x0000000000000000);
    test__fixunssfti(-0x1.FFFFFCp+62, 0x0000000000000000);
    test__fixunssfti(-0x1.FFFFFEp+126, 0x0000000000000000);
    test__fixunssfti(-0x1.FFFFFCp+126, 0x0000000000000000);
}

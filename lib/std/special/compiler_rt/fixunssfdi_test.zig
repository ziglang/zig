// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixunssfdi = @import("fixunssfdi.zig").__fixunssfdi;
const testing = @import("std").testing;

fn test__fixunssfdi(a: f32, expected: u64) void {
    const x = __fixunssfdi(a);
    testing.expect(x == expected);
}

test "fixunssfdi" {
    test__fixunssfdi(0.0, 0);

    test__fixunssfdi(0.5, 0);
    test__fixunssfdi(0.99, 0);
    test__fixunssfdi(1.0, 1);
    test__fixunssfdi(1.5, 1);
    test__fixunssfdi(1.99, 1);
    test__fixunssfdi(2.0, 2);
    test__fixunssfdi(2.01, 2);
    test__fixunssfdi(-0.5, 0);
    test__fixunssfdi(-0.99, 0);

    test__fixunssfdi(-1.0, 0);
    test__fixunssfdi(-1.5, 0);
    test__fixunssfdi(-1.99, 0);
    test__fixunssfdi(-2.0, 0);
    test__fixunssfdi(-2.01, 0);

    test__fixunssfdi(0x1.FFFFFEp+63, 0xFFFFFF0000000000);
    test__fixunssfdi(0x1.000000p+63, 0x8000000000000000);
    test__fixunssfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    test__fixunssfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    test__fixunssfdi(-0x1.FFFFFEp+62, 0x0000000000000000);
    test__fixunssfdi(-0x1.FFFFFCp+62, 0x0000000000000000);
}

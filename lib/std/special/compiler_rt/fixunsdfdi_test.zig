// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixunsdfdi = @import("fixunsdfdi.zig").__fixunsdfdi;
const testing = @import("std").testing;

fn test__fixunsdfdi(a: f64, expected: u64) void {
    const x = __fixunsdfdi(a);
    testing.expect(x == expected);
}

test "fixunsdfdi" {
    //test__fixunsdfdi(0.0, 0);
    //test__fixunsdfdi(0.5, 0);
    //test__fixunsdfdi(0.99, 0);
    test__fixunsdfdi(1.0, 1);
    test__fixunsdfdi(1.5, 1);
    test__fixunsdfdi(1.99, 1);
    test__fixunsdfdi(2.0, 2);
    test__fixunsdfdi(2.01, 2);
    test__fixunsdfdi(-0.5, 0);
    test__fixunsdfdi(-0.99, 0);
    test__fixunsdfdi(-1.0, 0);
    test__fixunsdfdi(-1.5, 0);
    test__fixunsdfdi(-1.99, 0);
    test__fixunsdfdi(-2.0, 0);
    test__fixunsdfdi(-2.01, 0);

    test__fixunsdfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    test__fixunsdfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    test__fixunsdfdi(-0x1.FFFFFEp+62, 0);
    test__fixunsdfdi(-0x1.FFFFFCp+62, 0);

    test__fixunsdfdi(0x1.FFFFFFFFFFFFFp+63, 0xFFFFFFFFFFFFF800);
    test__fixunsdfdi(0x1.0000000000000p+63, 0x8000000000000000);
    test__fixunsdfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    test__fixunsdfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);

    test__fixunsdfdi(-0x1.FFFFFFFFFFFFFp+62, 0);
    test__fixunsdfdi(-0x1.FFFFFFFFFFFFEp+62, 0);
}

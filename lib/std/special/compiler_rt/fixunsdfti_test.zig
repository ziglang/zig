// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixunsdfti = @import("fixunsdfti.zig").__fixunsdfti;
const testing = @import("std").testing;

fn test__fixunsdfti(a: f64, expected: u128) !void {
    const x = __fixunsdfti(a);
    try testing.expect(x == expected);
}

test "fixunsdfti" {
    try test__fixunsdfti(0.0, 0);

    try test__fixunsdfti(0.5, 0);
    try test__fixunsdfti(0.99, 0);
    try test__fixunsdfti(1.0, 1);
    try test__fixunsdfti(1.5, 1);
    try test__fixunsdfti(1.99, 1);
    try test__fixunsdfti(2.0, 2);
    try test__fixunsdfti(2.01, 2);
    try test__fixunsdfti(-0.5, 0);
    try test__fixunsdfti(-0.99, 0);
    try test__fixunsdfti(-1.0, 0);
    try test__fixunsdfti(-1.5, 0);
    try test__fixunsdfti(-1.99, 0);
    try test__fixunsdfti(-2.0, 0);
    try test__fixunsdfti(-2.01, 0);

    try test__fixunsdfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunsdfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    try test__fixunsdfti(-0x1.FFFFFEp+62, 0);
    try test__fixunsdfti(-0x1.FFFFFCp+62, 0);

    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+63, 0xFFFFFFFFFFFFF800);
    try test__fixunsdfti(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);

    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+127, 0xFFFFFFFFFFFFF8000000000000000000);
    try test__fixunsdfti(0x1.0000000000000p+127, 0x80000000000000000000000000000000);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFF8000000000000000000);
    try test__fixunsdfti(0x1.0000000000000p+128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    try test__fixunsdfti(-0x1.FFFFFFFFFFFFFp+62, 0);
    try test__fixunsdfti(-0x1.FFFFFFFFFFFFEp+62, 0);
}

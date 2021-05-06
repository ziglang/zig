// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixsfti = @import("fixsfti.zig").__fixsfti;
const std = @import("std");
const math = std.math;
const testing = std.testing;
const warn = std.debug.warn;

fn test__fixsfti(a: f32, expected: i128) !void {
    const x = __fixsfti(a);
    //warn("a={}:{x} x={}:{x} expected={}:{x}:@as(u128, {x})\n", .{a, @bitCast(u32, a), x, x, expected, expected, @bitCast(u128, expected)});
    try testing.expect(x == expected);
}

test "fixsfti" {
    //warn("\n", .{});
    try test__fixsfti(-math.f32_max, math.minInt(i128));

    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i128));
    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000000000000000000000000000);

    try test__fixsfti(-0x1.0000000000000p+127, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+126, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFEp+126, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFF0000000p+126, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFE0000000p+126, -0x7FFFFF80000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFC0000000p+126, -0x7FFFFF00000000000000000000000000);

    try test__fixsfti(-0x1.0000000000001p+63, -0x8000000000000000);
    try test__fixsfti(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+62, -0x8000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFEp+62, -0x8000000000000000);

    try test__fixsfti(-0x1.FFFFFFp+62, -0x8000000000000000);
    try test__fixsfti(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixsfti(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixsfti(-0x1.000000p+31, -0x80000000);
    try test__fixsfti(-0x1.FFFFFFp+30, -0x80000000);
    try test__fixsfti(-0x1.FFFFFEp+30, -0x7FFFFF80);
    try test__fixsfti(-0x1.FFFFFCp+30, -0x7FFFFF00);

    try test__fixsfti(-2.01, -2);
    try test__fixsfti(-2.0, -2);
    try test__fixsfti(-1.99, -1);
    try test__fixsfti(-1.0, -1);
    try test__fixsfti(-0.99, 0);
    try test__fixsfti(-0.5, 0);
    try test__fixsfti(-math.f32_min, 0);
    try test__fixsfti(0.0, 0);
    try test__fixsfti(math.f32_min, 0);
    try test__fixsfti(0.5, 0);
    try test__fixsfti(0.99, 0);
    try test__fixsfti(1.0, 1);
    try test__fixsfti(1.5, 1);
    try test__fixsfti(1.99, 1);
    try test__fixsfti(2.0, 2);
    try test__fixsfti(2.01, 2);

    try test__fixsfti(0x1.FFFFFCp+30, 0x7FFFFF00);
    try test__fixsfti(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixsfti(0x1.FFFFFFp+30, 0x80000000);
    try test__fixsfti(0x1.000000p+31, 0x80000000);

    try test__fixsfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixsfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixsfti(0x1.FFFFFFp+62, 0x8000000000000000);

    try test__fixsfti(0x1.FFFFFFFFFFFFEp+62, 0x8000000000000000);
    try test__fixsfti(0x1.FFFFFFFFFFFFFp+62, 0x8000000000000000);
    try test__fixsfti(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixsfti(0x1.0000000000001p+63, 0x8000000000000000);

    try test__fixsfti(0x1.FFFFFC0000000p+126, 0x7FFFFF00000000000000000000000000);
    try test__fixsfti(0x1.FFFFFE0000000p+126, 0x7FFFFF80000000000000000000000000);
    try test__fixsfti(0x1.FFFFFF0000000p+126, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    try test__fixsfti(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i128));

    try test__fixsfti(math.f32_max, math.maxInt(i128));
}

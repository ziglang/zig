// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixsfsi = @import("fixsfsi.zig").__fixsfsi;
const std = @import("std");
const math = std.math;
const testing = std.testing;
const warn = std.debug.warn;

fn test__fixsfsi(a: f32, expected: i32) void {
    const x = __fixsfsi(a);
    //warn("a={}:{x} x={}:{x} expected={}:{x}:@as(u32, {x})\n", .{a, @bitCast(u32, a), x, x, expected, expected, @bitCast(u32, expected)});
    testing.expect(x == expected);
}

test "fixsfsi" {
    //warn("\n", .{});
    test__fixsfsi(-math.f32_max, math.minInt(i32));

    test__fixsfsi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i32));
    test__fixsfsi(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000);

    test__fixsfsi(-0x1.0000000000000p+127, -0x80000000);
    test__fixsfsi(-0x1.FFFFFFFFFFFFFp+126, -0x80000000);
    test__fixsfsi(-0x1.FFFFFFFFFFFFEp+126, -0x80000000);

    test__fixsfsi(-0x1.0000000000001p+63, -0x80000000);
    test__fixsfsi(-0x1.0000000000000p+63, -0x80000000);
    test__fixsfsi(-0x1.FFFFFFFFFFFFFp+62, -0x80000000);
    test__fixsfsi(-0x1.FFFFFFFFFFFFEp+62, -0x80000000);

    test__fixsfsi(-0x1.FFFFFEp+62, -0x80000000);
    test__fixsfsi(-0x1.FFFFFCp+62, -0x80000000);

    test__fixsfsi(-0x1.000000p+31, -0x80000000);
    test__fixsfsi(-0x1.FFFFFFp+30, -0x80000000);
    test__fixsfsi(-0x1.FFFFFEp+30, -0x7FFFFF80);
    test__fixsfsi(-0x1.FFFFFCp+30, -0x7FFFFF00);

    test__fixsfsi(-2.01, -2);
    test__fixsfsi(-2.0, -2);
    test__fixsfsi(-1.99, -1);
    test__fixsfsi(-1.0, -1);
    test__fixsfsi(-0.99, 0);
    test__fixsfsi(-0.5, 0);
    test__fixsfsi(-math.f32_min, 0);
    test__fixsfsi(0.0, 0);
    test__fixsfsi(math.f32_min, 0);
    test__fixsfsi(0.5, 0);
    test__fixsfsi(0.99, 0);
    test__fixsfsi(1.0, 1);
    test__fixsfsi(1.5, 1);
    test__fixsfsi(1.99, 1);
    test__fixsfsi(2.0, 2);
    test__fixsfsi(2.01, 2);

    test__fixsfsi(0x1.FFFFFCp+30, 0x7FFFFF00);
    test__fixsfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    test__fixsfsi(0x1.FFFFFFp+30, 0x7FFFFFFF);
    test__fixsfsi(0x1.000000p+31, 0x7FFFFFFF);

    test__fixsfsi(0x1.FFFFFCp+62, 0x7FFFFFFF);
    test__fixsfsi(0x1.FFFFFEp+62, 0x7FFFFFFF);

    test__fixsfsi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFF);
    test__fixsfsi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFF);
    test__fixsfsi(0x1.0000000000000p+63, 0x7FFFFFFF);
    test__fixsfsi(0x1.0000000000001p+63, 0x7FFFFFFF);

    test__fixsfsi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFF);
    test__fixsfsi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFF);
    test__fixsfsi(0x1.0000000000000p+127, 0x7FFFFFFF);

    test__fixsfsi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFF);
    test__fixsfsi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i32));

    test__fixsfsi(math.f32_max, math.maxInt(i32));
}

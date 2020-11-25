// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __fixtfdi = @import("fixtfdi.zig").__fixtfdi;
const std = @import("std");
const math = std.math;
const testing = std.testing;
const warn = std.debug.warn;

fn test__fixtfdi(a: f128, expected: i64) void {
    const x = __fixtfdi(a);
    //warn("a={}:{x} x={}:{x} expected={}:{x}:@as(u64, {x})\n", .{a, @bitCast(u128, a), x, x, expected, expected, @bitCast(u64, expected)});
    testing.expect(x == expected);
}

test "fixtfdi" {
    //warn("\n", .{});
    test__fixtfdi(-math.f128_max, math.minInt(i64));

    test__fixtfdi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i64));
    test__fixtfdi(-0x1.FFFFFFFFFFFFFp+1023, -0x8000000000000000);

    test__fixtfdi(-0x1.0000000000000p+127, -0x8000000000000000);
    test__fixtfdi(-0x1.FFFFFFFFFFFFFp+126, -0x8000000000000000);
    test__fixtfdi(-0x1.FFFFFFFFFFFFEp+126, -0x8000000000000000);

    test__fixtfdi(-0x1.0000000000001p+63, -0x8000000000000000);
    test__fixtfdi(-0x1.0000000000000p+63, -0x8000000000000000);
    test__fixtfdi(-0x1.FFFFFFFFFFFFFp+62, -0x7FFFFFFFFFFFFC00);
    test__fixtfdi(-0x1.FFFFFFFFFFFFEp+62, -0x7FFFFFFFFFFFF800);

    test__fixtfdi(-0x1.FFFFFEp+62, -0x7FFFFF8000000000);
    test__fixtfdi(-0x1.FFFFFCp+62, -0x7FFFFF0000000000);

    test__fixtfdi(-0x1.000000p+31, -0x80000000);
    test__fixtfdi(-0x1.FFFFFFp+30, -0x7FFFFFC0);
    test__fixtfdi(-0x1.FFFFFEp+30, -0x7FFFFF80);
    test__fixtfdi(-0x1.FFFFFCp+30, -0x7FFFFF00);

    test__fixtfdi(-2.01, -2);
    test__fixtfdi(-2.0, -2);
    test__fixtfdi(-1.99, -1);
    test__fixtfdi(-1.0, -1);
    test__fixtfdi(-0.99, 0);
    test__fixtfdi(-0.5, 0);
    test__fixtfdi(-math.f64_min, 0);
    test__fixtfdi(0.0, 0);
    test__fixtfdi(math.f64_min, 0);
    test__fixtfdi(0.5, 0);
    test__fixtfdi(0.99, 0);
    test__fixtfdi(1.0, 1);
    test__fixtfdi(1.5, 1);
    test__fixtfdi(1.99, 1);
    test__fixtfdi(2.0, 2);
    test__fixtfdi(2.01, 2);

    test__fixtfdi(0x1.FFFFFCp+30, 0x7FFFFF00);
    test__fixtfdi(0x1.FFFFFEp+30, 0x7FFFFF80);
    test__fixtfdi(0x1.FFFFFFp+30, 0x7FFFFFC0);
    test__fixtfdi(0x1.000000p+31, 0x80000000);

    test__fixtfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    test__fixtfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);

    test__fixtfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);
    test__fixtfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    test__fixtfdi(0x1.0000000000000p+63, 0x7FFFFFFFFFFFFFFF);
    test__fixtfdi(0x1.0000000000001p+63, 0x7FFFFFFFFFFFFFFF);

    test__fixtfdi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFFFFF);
    test__fixtfdi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFFFF);
    test__fixtfdi(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFF);

    test__fixtfdi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFF);
    test__fixtfdi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i64));

    test__fixtfdi(math.f128_max, math.maxInt(i64));
}

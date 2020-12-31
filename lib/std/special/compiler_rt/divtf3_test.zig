// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const math = std.math;
const testing = std.testing;

const __divtf3 = @import("divtf3.zig").__divtf3;

fn compareResultLD(result: f128, expectedHi: u64, expectedLo: u64) bool {
    const rep = @bitCast(u128, result);
    const hi = @truncate(u64, rep >> 64);
    const lo = @truncate(u64, rep);

    if (hi == expectedHi and lo == expectedLo) {
        return true;
    }
    // test other possible NaN representation(signal NaN)
    else if (expectedHi == 0x7fff800000000000 and expectedLo == 0) {
        if ((hi & 0x7fff000000000000) == 0x7fff000000000000 and
            ((hi & 0xffffffffffff) > 0 or lo > 0))
        {
            return true;
        }
    }
    return false;
}

fn test__divtf3(a: f128, b: f128, expectedHi: u64, expectedLo: u64) void {
    const x = __divtf3(a, b);
    const ret = compareResultLD(x, expectedHi, expectedLo);
    testing.expect(ret == true);
}

test "divtf3" {
    // qNaN / any = qNaN
    test__divtf3(math.qnan_f128, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0);
    // NaN / any = NaN
    test__divtf3(math.nan_f128, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0);
    // inf / any = inf
    test__divtf3(math.inf_f128, 0x1.23456789abcdefp+5, 0x7fff000000000000, 0);

    test__divtf3(0x1.a23b45362464523375893ab4cdefp+5, 0x1.eedcbaba3a94546558237654321fp-1, 0x4004b0b72924d407, 0x0717e84356c6eba2);
    test__divtf3(0x1.a2b34c56d745382f9abf2c3dfeffp-50, 0x1.ed2c3ba15935332532287654321fp-9, 0x3fd5b2af3f828c9b, 0x40e51f64cde8b1f2);
    test__divtf3(0x1.2345f6aaaa786555f42432abcdefp+456, 0x1.edacbba9874f765463544dd3621fp+6400, 0x28c62e15dc464466, 0xb5a07586348557ac);
    test__divtf3(0x1.2d3456f789ba6322bc665544edefp-234, 0x1.eddcdba39f3c8b7a36564354321fp-4455, 0x507b38442b539266, 0x22ce0f1d024e1252);
    test__divtf3(0x1.2345f6b77b7a8953365433abcdefp+234, 0x1.edcba987d6bb3aa467754354321fp-4055, 0x50bf2e02f0798d36, 0x5e6fcb6b60044078);
    test__divtf3(6.72420628622418701252535563464350521E-4932, 2.0, 0x0001000000000000, 0);
}

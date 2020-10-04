// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std");
const maxInt = std.math.maxInt;

fn floatsiXf(comptime T: type, a: i32) T {
    @setRuntimeSafety(builtin.is_test);

    const bits = @typeInfo(T).Float.bits;
    const Z = std.meta.Int(false, bits);
    const S = std.meta.Int(false, bits - @clz(Z, @as(Z, bits) - 1));

    if (a == 0) {
        return @as(T, 0.0);
    }

    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);
    const exponentBias = ((1 << exponentBits - 1) - 1);

    const implicitBit = @as(Z, 1) << significandBits;
    const signBit = @as(Z, 1 << bits - 1);

    const sign = a >> 31;
    // Take absolute value of a via abs(x) = (x^(x >> 31)) - (x >> 31).
    const abs_a = (a ^ sign) -% sign;
    // The exponent is the width of abs(a)
    const exp = @as(Z, 31 - @clz(i32, abs_a));

    const sign_bit = if (sign < 0) signBit else 0;

    var mantissa: Z = undefined;
    // Shift a into the significand field and clear the implicit bit.
    if (exp <= significandBits) {
        // No rounding needed
        const shift = @intCast(S, significandBits - exp);
        mantissa = @intCast(Z, @bitCast(u32, abs_a)) << shift ^ implicitBit;
    } else {
        const shift = @intCast(S, exp - significandBits);
        // Round to the nearest number after truncation
        mantissa = @intCast(Z, @bitCast(u32, abs_a)) >> shift ^ implicitBit;
        // Align to the left and check if the truncated part is halfway over
        const round = @bitCast(u32, abs_a) << @intCast(u5, 31 - shift);
        mantissa += @boolToInt(round > 0x80000000);
        // Tie to even
        mantissa += mantissa & 1;
    }

    // Use the addition instead of a or since we may have a carry from the
    // mantissa to the exponent
    var result = mantissa;
    result += (exp + exponentBias) << significandBits;
    result += sign_bit;

    return @bitCast(T, result);
}

pub fn __floatsisf(arg: i32) callconv(.C) f32 {
    @setRuntimeSafety(builtin.is_test);
    return @call(.{ .modifier = .always_inline }, floatsiXf, .{ f32, arg });
}

pub fn __floatsidf(arg: i32) callconv(.C) f64 {
    @setRuntimeSafety(builtin.is_test);
    return @call(.{ .modifier = .always_inline }, floatsiXf, .{ f64, arg });
}

pub fn __floatsitf(arg: i32) callconv(.C) f128 {
    @setRuntimeSafety(builtin.is_test);
    return @call(.{ .modifier = .always_inline }, floatsiXf, .{ f128, arg });
}

pub fn __aeabi_i2d(arg: i32) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __floatsidf, .{arg});
}

pub fn __aeabi_i2f(arg: i32) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __floatsisf, .{arg});
}

fn test_one_floatsitf(a: i32, expected: u128) void {
    const r = __floatsitf(a);
    std.testing.expect(@bitCast(u128, r) == expected);
}

fn test_one_floatsidf(a: i32, expected: u64) void {
    const r = __floatsidf(a);
    std.testing.expect(@bitCast(u64, r) == expected);
}

fn test_one_floatsisf(a: i32, expected: u32) void {
    const r = __floatsisf(a);
    std.testing.expect(@bitCast(u32, r) == expected);
}

test "floatsidf" {
    test_one_floatsidf(0, 0x0000000000000000);
    test_one_floatsidf(1, 0x3ff0000000000000);
    test_one_floatsidf(-1, 0xbff0000000000000);
    test_one_floatsidf(0x7FFFFFFF, 0x41dfffffffc00000);
    test_one_floatsidf(@bitCast(i32, @intCast(u32, 0x80000000)), 0xc1e0000000000000);
}

test "floatsisf" {
    test_one_floatsisf(0, 0x00000000);
    test_one_floatsisf(1, 0x3f800000);
    test_one_floatsisf(-1, 0xbf800000);
    test_one_floatsisf(0x7FFFFFFF, 0x4f000000);
    test_one_floatsisf(@bitCast(i32, @intCast(u32, 0x80000000)), 0xcf000000);
}

test "floatsitf" {
    test_one_floatsitf(0, 0);
    test_one_floatsitf(0x7FFFFFFF, 0x401dfffffffc00000000000000000000);
    test_one_floatsitf(0x12345678, 0x401b2345678000000000000000000000);
    test_one_floatsitf(-0x12345678, 0xc01b2345678000000000000000000000);
    test_one_floatsitf(@bitCast(i32, @intCast(u32, 0xffffffff)), 0xbfff0000000000000000000000000000);
    test_one_floatsitf(@bitCast(i32, @intCast(u32, 0x80000000)), 0xc01e0000000000000000000000000000);
}

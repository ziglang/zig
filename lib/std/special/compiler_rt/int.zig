// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Builtin functions that operate on integer types
const builtin = @import("builtin");
const testing = @import("std").testing;
const maxInt = @import("std").math.maxInt;
const minInt = @import("std").math.minInt;

const udivmod = @import("udivmod.zig").udivmod;

pub fn __divmoddi4(a: i64, b: i64, rem: *i64) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);

    const d = __divdi3(a, b);
    rem.* = a -% (d *% b);
    return d;
}

pub fn __udivmoddi4(a: u64, b: u64, maybe_rem: ?*u64) callconv(.C) u64 {
    @setRuntimeSafety(builtin.is_test);
    return udivmod(u64, a, b, maybe_rem);
}

test "test_udivmoddi4" {
    _ = @import("udivmoddi4_test.zig");
}

pub fn __divdi3(a: i64, b: i64) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);

    // Set aside the sign of the quotient.
    const sign = @bitCast(u64, (a ^ b) >> 63);
    // Take absolute value of a and b via abs(x) = (x^(x >> 63)) - (x >> 63).
    const abs_a = (a ^ (a >> 63)) -% (a >> 63);
    const abs_b = (b ^ (b >> 63)) -% (b >> 63);
    // Unsigned division
    const res = __udivmoddi4(@bitCast(u64, abs_a), @bitCast(u64, abs_b), null);
    // Apply sign of quotient to result and return.
    return @bitCast(i64, (res ^ sign) -% sign);
}

test "test_divdi3" {
    const cases = [_][3]i64{
        [_]i64{ 0, 1, 0 },
        [_]i64{ 0, -1, 0 },
        [_]i64{ 2, 1, 2 },
        [_]i64{ 2, -1, -2 },
        [_]i64{ -2, 1, -2 },
        [_]i64{ -2, -1, 2 },

        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 1, @bitCast(i64, @as(u64, 0x8000000000000000)) },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -1, @bitCast(i64, @as(u64, 0x8000000000000000)) },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -2, 0x4000000000000000 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 2, @bitCast(i64, @as(u64, 0xC000000000000000)) },
    };

    for (cases) |case| {
        test_one_divdi3(case[0], case[1], case[2]);
    }
}

fn test_one_divdi3(a: i64, b: i64, expected_q: i64) void {
    const q: i64 = __divdi3(a, b);
    testing.expect(q == expected_q);
}

pub fn __moddi3(a: i64, b: i64) callconv(.C) i64 {
    @setRuntimeSafety(builtin.is_test);

    // Take absolute value of a and b via abs(x) = (x^(x >> 63)) - (x >> 63).
    const abs_a = (a ^ (a >> 63)) -% (a >> 63);
    const abs_b = (b ^ (b >> 63)) -% (b >> 63);
    // Unsigned division
    var r: u64 = undefined;
    _ = __udivmoddi4(@bitCast(u64, abs_a), @bitCast(u64, abs_b), &r);
    // Apply the sign of the dividend and return.
    return (@bitCast(i64, r) ^ (a >> 63)) -% (a >> 63);
}

test "test_moddi3" {
    const cases = [_][3]i64{
        [_]i64{ 0, 1, 0 },
        [_]i64{ 0, -1, 0 },
        [_]i64{ 5, 3, 2 },
        [_]i64{ 5, -3, 2 },
        [_]i64{ -5, 3, -2 },
        [_]i64{ -5, -3, -2 },

        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 1, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -1, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 2, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -2, 0 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), 3, -2 },
        [_]i64{ @bitCast(i64, @as(u64, 0x8000000000000000)), -3, -2 },
    };

    for (cases) |case| {
        test_one_moddi3(case[0], case[1], case[2]);
    }
}

fn test_one_moddi3(a: i64, b: i64, expected_r: i64) void {
    const r: i64 = __moddi3(a, b);
    testing.expect(r == expected_r);
}

pub fn __udivdi3(a: u64, b: u64) callconv(.C) u64 {
    @setRuntimeSafety(builtin.is_test);
    return __udivmoddi4(a, b, null);
}

pub fn __umoddi3(a: u64, b: u64) callconv(.C) u64 {
    @setRuntimeSafety(builtin.is_test);

    var r: u64 = undefined;
    _ = __udivmoddi4(a, b, &r);
    return r;
}

test "test_umoddi3" {
    test_one_umoddi3(0, 1, 0);
    test_one_umoddi3(2, 1, 0);
    test_one_umoddi3(0x8000000000000000, 1, 0x0);
    test_one_umoddi3(0x8000000000000000, 2, 0x0);
    test_one_umoddi3(0xFFFFFFFFFFFFFFFF, 2, 0x1);
}

fn test_one_umoddi3(a: u64, b: u64, expected_r: u64) void {
    const r = __umoddi3(a, b);
    testing.expect(r == expected_r);
}

pub fn __divmodsi4(a: i32, b: i32, rem: *i32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);

    const d = __divsi3(a, b);
    rem.* = a -% (d * b);
    return d;
}

test "test_divmodsi4" {
    const cases = [_][4]i32{
        [_]i32{ 0, 1, 0, 0 },
        [_]i32{ 0, -1, 0, 0 },
        [_]i32{ 2, 1, 2, 0 },
        [_]i32{ 2, -1, -2, 0 },
        [_]i32{ -2, 1, -2, 0 },
        [_]i32{ -2, -1, 2, 0 },
        [_]i32{ 7, 5, 1, 2 },
        [_]i32{ -7, 5, -1, -2 },
        [_]i32{ 19, 5, 3, 4 },
        [_]i32{ 19, -5, -3, 4 },

        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), 8, @bitCast(i32, @as(u32, 0xf0000000)), 0 },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000007)), 8, @bitCast(i32, @as(u32, 0xf0000001)), -1 },
    };

    for (cases) |case| {
        test_one_divmodsi4(case[0], case[1], case[2], case[3]);
    }
}

fn test_one_divmodsi4(a: i32, b: i32, expected_q: i32, expected_r: i32) void {
    var r: i32 = undefined;
    const q: i32 = __divmodsi4(a, b, &r);
    testing.expect(q == expected_q and r == expected_r);
}

pub fn __udivmodsi4(a: u32, b: u32, rem: *u32) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);

    const d = __udivsi3(a, b);
    rem.* = @bitCast(u32, @bitCast(i32, a) -% (@bitCast(i32, d) * @bitCast(i32, b)));
    return d;
}

pub fn __divsi3(n: i32, d: i32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);

    // Set aside the sign of the quotient.
    const sign = @bitCast(u32, (n ^ d) >> 31);
    // Take absolute value of a and b via abs(x) = (x^(x >> 31)) - (x >> 31).
    const abs_n = (n ^ (n >> 31)) -% (n >> 31);
    const abs_d = (d ^ (d >> 31)) -% (d >> 31);
    // abs(a) / abs(b)
    const res = @bitCast(u32, abs_n) / @bitCast(u32, abs_d);
    // Apply sign of quotient to result and return.
    return @bitCast(i32, (res ^ sign) -% sign);
}

test "test_divsi3" {
    const cases = [_][3]i32{
        [_]i32{ 0, 1, 0 },
        [_]i32{ 0, -1, 0 },
        [_]i32{ 2, 1, 2 },
        [_]i32{ 2, -1, -2 },
        [_]i32{ -2, 1, -2 },
        [_]i32{ -2, -1, 2 },

        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), 1, @bitCast(i32, @as(u32, 0x80000000)) },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), -1, @bitCast(i32, @as(u32, 0x80000000)) },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), -2, 0x40000000 },
        [_]i32{ @bitCast(i32, @as(u32, 0x80000000)), 2, @bitCast(i32, @as(u32, 0xC0000000)) },
    };

    for (cases) |case| {
        test_one_divsi3(case[0], case[1], case[2]);
    }
}

fn test_one_divsi3(a: i32, b: i32, expected_q: i32) void {
    const q: i32 = __divsi3(a, b);
    testing.expect(q == expected_q);
}

pub fn __udivsi3(n: u32, d: u32) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);

    const n_uword_bits: c_uint = 32;
    // special cases
    if (d == 0) return 0; // ?!
    if (n == 0) return 0;
    var sr = @bitCast(c_uint, @as(c_int, @clz(u32, d)) - @as(c_int, @clz(u32, n)));
    // 0 <= sr <= n_uword_bits - 1 or sr large
    if (sr > n_uword_bits - 1) {
        // d > r
        return 0;
    }
    if (sr == n_uword_bits - 1) {
        // d == 1
        return n;
    }
    sr += 1;
    // 1 <= sr <= n_uword_bits - 1
    // Not a special case
    var q: u32 = n << @intCast(u5, n_uword_bits - sr);
    var r: u32 = n >> @intCast(u5, sr);
    var carry: u32 = 0;
    while (sr > 0) : (sr -= 1) {
        // r:q = ((r:q)  << 1) | carry
        r = (r << 1) | (q >> @intCast(u5, n_uword_bits - 1));
        q = (q << 1) | carry;
        // carry = 0;
        // if (r.all >= d.all)
        // {
        //      r.all -= d.all;
        //      carry = 1;
        // }
        const s = @bitCast(i32, d -% r -% 1) >> @intCast(u5, n_uword_bits - 1);
        carry = @intCast(u32, s & 1);
        r -= d & @bitCast(u32, s);
    }
    q = (q << 1) | carry;
    return q;
}

test "test_udivsi3" {
    const cases = [_][3]u32{
        [_]u32{ 0x00000000, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000003, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000000, 0x078644FA, 0x00000000 },
        [_]u32{ 0x00000000, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x00000000, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x00000000, 0x80000000, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x00000001, 0x00000001, 0x00000001 },
        [_]u32{ 0x00000001, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000001, 0x00000003, 0x00000000 },
        [_]u32{ 0x00000001, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000001, 0x078644FA, 0x00000000 },
        [_]u32{ 0x00000001, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x00000001, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x00000001, 0x80000000, 0x00000000 },
        [_]u32{ 0x00000001, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x00000001, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x00000001, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x00000002, 0x00000001, 0x00000002 },
        [_]u32{ 0x00000002, 0x00000002, 0x00000001 },
        [_]u32{ 0x00000002, 0x00000003, 0x00000000 },
        [_]u32{ 0x00000002, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000002, 0x078644FA, 0x00000000 },
        [_]u32{ 0x00000002, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x00000002, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x00000002, 0x80000000, 0x00000000 },
        [_]u32{ 0x00000002, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x00000002, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x00000002, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x00000003, 0x00000001, 0x00000003 },
        [_]u32{ 0x00000003, 0x00000002, 0x00000001 },
        [_]u32{ 0x00000003, 0x00000003, 0x00000001 },
        [_]u32{ 0x00000003, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000003, 0x078644FA, 0x00000000 },
        [_]u32{ 0x00000003, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x00000003, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x00000003, 0x80000000, 0x00000000 },
        [_]u32{ 0x00000003, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x00000003, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x00000003, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x00000010, 0x00000001, 0x00000010 },
        [_]u32{ 0x00000010, 0x00000002, 0x00000008 },
        [_]u32{ 0x00000010, 0x00000003, 0x00000005 },
        [_]u32{ 0x00000010, 0x00000010, 0x00000001 },
        [_]u32{ 0x00000010, 0x078644FA, 0x00000000 },
        [_]u32{ 0x00000010, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x00000010, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x00000010, 0x80000000, 0x00000000 },
        [_]u32{ 0x00000010, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x00000010, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x00000010, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x078644FA, 0x00000001, 0x078644FA },
        [_]u32{ 0x078644FA, 0x00000002, 0x03C3227D },
        [_]u32{ 0x078644FA, 0x00000003, 0x028216FE },
        [_]u32{ 0x078644FA, 0x00000010, 0x0078644F },
        [_]u32{ 0x078644FA, 0x078644FA, 0x00000001 },
        [_]u32{ 0x078644FA, 0x0747AE14, 0x00000001 },
        [_]u32{ 0x078644FA, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x078644FA, 0x80000000, 0x00000000 },
        [_]u32{ 0x078644FA, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x078644FA, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x078644FA, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x00000001, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0x00000002, 0x03A3D70A },
        [_]u32{ 0x0747AE14, 0x00000003, 0x026D3A06 },
        [_]u32{ 0x0747AE14, 0x00000010, 0x00747AE1 },
        [_]u32{ 0x0747AE14, 0x078644FA, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x0747AE14, 0x00000001 },
        [_]u32{ 0x0747AE14, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x80000000, 0x00000000 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0x00000001, 0x7FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0x00000002, 0x3FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0x00000003, 0x2AAAAAAA },
        [_]u32{ 0x7FFFFFFF, 0x00000010, 0x07FFFFFF },
        [_]u32{ 0x7FFFFFFF, 0x078644FA, 0x00000011 },
        [_]u32{ 0x7FFFFFFF, 0x0747AE14, 0x00000011 },
        [_]u32{ 0x7FFFFFFF, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0x7FFFFFFF, 0x80000000, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x80000000, 0x00000001, 0x80000000 },
        [_]u32{ 0x80000000, 0x00000002, 0x40000000 },
        [_]u32{ 0x80000000, 0x00000003, 0x2AAAAAAA },
        [_]u32{ 0x80000000, 0x00000010, 0x08000000 },
        [_]u32{ 0x80000000, 0x078644FA, 0x00000011 },
        [_]u32{ 0x80000000, 0x0747AE14, 0x00000011 },
        [_]u32{ 0x80000000, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0x80000000, 0x80000000, 0x00000001 },
        [_]u32{ 0x80000000, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0xFFFFFFFD, 0x00000001, 0xFFFFFFFD },
        [_]u32{ 0xFFFFFFFD, 0x00000002, 0x7FFFFFFE },
        [_]u32{ 0xFFFFFFFD, 0x00000003, 0x55555554 },
        [_]u32{ 0xFFFFFFFD, 0x00000010, 0x0FFFFFFF },
        [_]u32{ 0xFFFFFFFD, 0x078644FA, 0x00000022 },
        [_]u32{ 0xFFFFFFFD, 0x0747AE14, 0x00000023 },
        [_]u32{ 0xFFFFFFFD, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0xFFFFFFFD, 0x80000000, 0x00000001 },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFD, 0x00000001 },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0x00000001, 0xFFFFFFFE },
        [_]u32{ 0xFFFFFFFE, 0x00000002, 0x7FFFFFFF },
        [_]u32{ 0xFFFFFFFE, 0x00000003, 0x55555554 },
        [_]u32{ 0xFFFFFFFE, 0x00000010, 0x0FFFFFFF },
        [_]u32{ 0xFFFFFFFE, 0x078644FA, 0x00000022 },
        [_]u32{ 0xFFFFFFFE, 0x0747AE14, 0x00000023 },
        [_]u32{ 0xFFFFFFFE, 0x7FFFFFFF, 0x00000002 },
        [_]u32{ 0xFFFFFFFE, 0x80000000, 0x00000001 },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFD, 0x00000001 },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFE, 0x00000001 },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0xFFFFFFFF, 0x00000001, 0xFFFFFFFF },
        [_]u32{ 0xFFFFFFFF, 0x00000002, 0x7FFFFFFF },
        [_]u32{ 0xFFFFFFFF, 0x00000003, 0x55555555 },
        [_]u32{ 0xFFFFFFFF, 0x00000010, 0x0FFFFFFF },
        [_]u32{ 0xFFFFFFFF, 0x078644FA, 0x00000022 },
        [_]u32{ 0xFFFFFFFF, 0x0747AE14, 0x00000023 },
        [_]u32{ 0xFFFFFFFF, 0x7FFFFFFF, 0x00000002 },
        [_]u32{ 0xFFFFFFFF, 0x80000000, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFD, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFE, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFF, 0x00000001 },
    };

    for (cases) |case| {
        test_one_udivsi3(case[0], case[1], case[2]);
    }
}

fn test_one_udivsi3(a: u32, b: u32, expected_q: u32) void {
    const q: u32 = __udivsi3(a, b);
    testing.expect(q == expected_q);
}

pub fn __modsi3(n: i32, d: i32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);

    return n -% __divsi3(n, d) *% d;
}

test "test_modsi3" {
    const cases = [_][3]i32{
        [_]i32{ 0, 1, 0 },
        [_]i32{ 0, -1, 0 },
        [_]i32{ 5, 3, 2 },
        [_]i32{ 5, -3, 2 },
        [_]i32{ -5, 3, -2 },
        [_]i32{ -5, -3, -2 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), 1, 0x0 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), 2, 0x0 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), -2, 0x0 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), 3, -2 },
        [_]i32{ @bitCast(i32, @intCast(u32, 0x80000000)), -3, -2 },
    };

    for (cases) |case| {
        test_one_modsi3(case[0], case[1], case[2]);
    }
}

fn test_one_modsi3(a: i32, b: i32, expected_r: i32) void {
    const r: i32 = __modsi3(a, b);
    testing.expect(r == expected_r);
}

pub fn __umodsi3(n: u32, d: u32) callconv(.C) u32 {
    @setRuntimeSafety(builtin.is_test);

    return n -% __udivsi3(n, d) *% d;
}

test "test_umodsi3" {
    const cases = [_][3]u32{
        [_]u32{ 0x00000000, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000003, 0x00000000 },
        [_]u32{ 0x00000000, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000000, 0x078644FA, 0x00000000 },
        [_]u32{ 0x00000000, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x00000000, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x00000000, 0x80000000, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0x00000000, 0xFFFFFFFF, 0x00000000 },
        [_]u32{ 0x00000001, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000001, 0x00000002, 0x00000001 },
        [_]u32{ 0x00000001, 0x00000003, 0x00000001 },
        [_]u32{ 0x00000001, 0x00000010, 0x00000001 },
        [_]u32{ 0x00000001, 0x078644FA, 0x00000001 },
        [_]u32{ 0x00000001, 0x0747AE14, 0x00000001 },
        [_]u32{ 0x00000001, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0x00000001, 0x80000000, 0x00000001 },
        [_]u32{ 0x00000001, 0xFFFFFFFD, 0x00000001 },
        [_]u32{ 0x00000001, 0xFFFFFFFE, 0x00000001 },
        [_]u32{ 0x00000001, 0xFFFFFFFF, 0x00000001 },
        [_]u32{ 0x00000002, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000002, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000002, 0x00000003, 0x00000002 },
        [_]u32{ 0x00000002, 0x00000010, 0x00000002 },
        [_]u32{ 0x00000002, 0x078644FA, 0x00000002 },
        [_]u32{ 0x00000002, 0x0747AE14, 0x00000002 },
        [_]u32{ 0x00000002, 0x7FFFFFFF, 0x00000002 },
        [_]u32{ 0x00000002, 0x80000000, 0x00000002 },
        [_]u32{ 0x00000002, 0xFFFFFFFD, 0x00000002 },
        [_]u32{ 0x00000002, 0xFFFFFFFE, 0x00000002 },
        [_]u32{ 0x00000002, 0xFFFFFFFF, 0x00000002 },
        [_]u32{ 0x00000003, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000003, 0x00000002, 0x00000001 },
        [_]u32{ 0x00000003, 0x00000003, 0x00000000 },
        [_]u32{ 0x00000003, 0x00000010, 0x00000003 },
        [_]u32{ 0x00000003, 0x078644FA, 0x00000003 },
        [_]u32{ 0x00000003, 0x0747AE14, 0x00000003 },
        [_]u32{ 0x00000003, 0x7FFFFFFF, 0x00000003 },
        [_]u32{ 0x00000003, 0x80000000, 0x00000003 },
        [_]u32{ 0x00000003, 0xFFFFFFFD, 0x00000003 },
        [_]u32{ 0x00000003, 0xFFFFFFFE, 0x00000003 },
        [_]u32{ 0x00000003, 0xFFFFFFFF, 0x00000003 },
        [_]u32{ 0x00000010, 0x00000001, 0x00000000 },
        [_]u32{ 0x00000010, 0x00000002, 0x00000000 },
        [_]u32{ 0x00000010, 0x00000003, 0x00000001 },
        [_]u32{ 0x00000010, 0x00000010, 0x00000000 },
        [_]u32{ 0x00000010, 0x078644FA, 0x00000010 },
        [_]u32{ 0x00000010, 0x0747AE14, 0x00000010 },
        [_]u32{ 0x00000010, 0x7FFFFFFF, 0x00000010 },
        [_]u32{ 0x00000010, 0x80000000, 0x00000010 },
        [_]u32{ 0x00000010, 0xFFFFFFFD, 0x00000010 },
        [_]u32{ 0x00000010, 0xFFFFFFFE, 0x00000010 },
        [_]u32{ 0x00000010, 0xFFFFFFFF, 0x00000010 },
        [_]u32{ 0x078644FA, 0x00000001, 0x00000000 },
        [_]u32{ 0x078644FA, 0x00000002, 0x00000000 },
        [_]u32{ 0x078644FA, 0x00000003, 0x00000000 },
        [_]u32{ 0x078644FA, 0x00000010, 0x0000000A },
        [_]u32{ 0x078644FA, 0x078644FA, 0x00000000 },
        [_]u32{ 0x078644FA, 0x0747AE14, 0x003E96E6 },
        [_]u32{ 0x078644FA, 0x7FFFFFFF, 0x078644FA },
        [_]u32{ 0x078644FA, 0x80000000, 0x078644FA },
        [_]u32{ 0x078644FA, 0xFFFFFFFD, 0x078644FA },
        [_]u32{ 0x078644FA, 0xFFFFFFFE, 0x078644FA },
        [_]u32{ 0x078644FA, 0xFFFFFFFF, 0x078644FA },
        [_]u32{ 0x0747AE14, 0x00000001, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x00000002, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x00000003, 0x00000002 },
        [_]u32{ 0x0747AE14, 0x00000010, 0x00000004 },
        [_]u32{ 0x0747AE14, 0x078644FA, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0x0747AE14, 0x00000000 },
        [_]u32{ 0x0747AE14, 0x7FFFFFFF, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0x80000000, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFD, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFE, 0x0747AE14 },
        [_]u32{ 0x0747AE14, 0xFFFFFFFF, 0x0747AE14 },
        [_]u32{ 0x7FFFFFFF, 0x00000001, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0x00000002, 0x00000001 },
        [_]u32{ 0x7FFFFFFF, 0x00000003, 0x00000001 },
        [_]u32{ 0x7FFFFFFF, 0x00000010, 0x0000000F },
        [_]u32{ 0x7FFFFFFF, 0x078644FA, 0x00156B65 },
        [_]u32{ 0x7FFFFFFF, 0x0747AE14, 0x043D70AB },
        [_]u32{ 0x7FFFFFFF, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0x7FFFFFFF, 0x80000000, 0x7FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFD, 0x7FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFE, 0x7FFFFFFF },
        [_]u32{ 0x7FFFFFFF, 0xFFFFFFFF, 0x7FFFFFFF },
        [_]u32{ 0x80000000, 0x00000001, 0x00000000 },
        [_]u32{ 0x80000000, 0x00000002, 0x00000000 },
        [_]u32{ 0x80000000, 0x00000003, 0x00000002 },
        [_]u32{ 0x80000000, 0x00000010, 0x00000000 },
        [_]u32{ 0x80000000, 0x078644FA, 0x00156B66 },
        [_]u32{ 0x80000000, 0x0747AE14, 0x043D70AC },
        [_]u32{ 0x80000000, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0x80000000, 0x80000000, 0x00000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFD, 0x80000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFE, 0x80000000 },
        [_]u32{ 0x80000000, 0xFFFFFFFF, 0x80000000 },
        [_]u32{ 0xFFFFFFFD, 0x00000001, 0x00000000 },
        [_]u32{ 0xFFFFFFFD, 0x00000002, 0x00000001 },
        [_]u32{ 0xFFFFFFFD, 0x00000003, 0x00000001 },
        [_]u32{ 0xFFFFFFFD, 0x00000010, 0x0000000D },
        [_]u32{ 0xFFFFFFFD, 0x078644FA, 0x002AD6C9 },
        [_]u32{ 0xFFFFFFFD, 0x0747AE14, 0x01333341 },
        [_]u32{ 0xFFFFFFFD, 0x7FFFFFFF, 0x7FFFFFFE },
        [_]u32{ 0xFFFFFFFD, 0x80000000, 0x7FFFFFFD },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFD, 0x00000000 },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFE, 0xFFFFFFFD },
        [_]u32{ 0xFFFFFFFD, 0xFFFFFFFF, 0xFFFFFFFD },
        [_]u32{ 0xFFFFFFFE, 0x00000001, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0x00000002, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0x00000003, 0x00000002 },
        [_]u32{ 0xFFFFFFFE, 0x00000010, 0x0000000E },
        [_]u32{ 0xFFFFFFFE, 0x078644FA, 0x002AD6CA },
        [_]u32{ 0xFFFFFFFE, 0x0747AE14, 0x01333342 },
        [_]u32{ 0xFFFFFFFE, 0x7FFFFFFF, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0x80000000, 0x7FFFFFFE },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFD, 0x00000001 },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFE, 0x00000000 },
        [_]u32{ 0xFFFFFFFE, 0xFFFFFFFF, 0xFFFFFFFE },
        [_]u32{ 0xFFFFFFFF, 0x00000001, 0x00000000 },
        [_]u32{ 0xFFFFFFFF, 0x00000002, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0x00000003, 0x00000000 },
        [_]u32{ 0xFFFFFFFF, 0x00000010, 0x0000000F },
        [_]u32{ 0xFFFFFFFF, 0x078644FA, 0x002AD6CB },
        [_]u32{ 0xFFFFFFFF, 0x0747AE14, 0x01333343 },
        [_]u32{ 0xFFFFFFFF, 0x7FFFFFFF, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0x80000000, 0x7FFFFFFF },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFD, 0x00000002 },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFE, 0x00000001 },
        [_]u32{ 0xFFFFFFFF, 0xFFFFFFFF, 0x00000000 },
    };

    for (cases) |case| {
        test_one_umodsi3(case[0], case[1], case[2]);
    }
}

fn test_one_umodsi3(a: u32, b: u32, expected_r: u32) void {
    const r: u32 = __umodsi3(a, b);
    testing.expect(r == expected_r);
}

pub fn __mulsi3(a: i32, b: i32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);

    var ua = @bitCast(u32, a);
    var ub = @bitCast(u32, b);
    var r: u32 = 0;

    while (ua > 0) {
        if ((ua & 1) != 0) r +%= ub;
        ua >>= 1;
        ub <<= 1;
    }

    return @bitCast(i32, r);
}

fn test_one_mulsi3(a: i32, b: i32, result: i32) void {
    testing.expectEqual(result, __mulsi3(a, b));
}

test "mulsi3" {
    test_one_mulsi3(0, 0, 0);
    test_one_mulsi3(0, 1, 0);
    test_one_mulsi3(1, 0, 0);
    test_one_mulsi3(0, 10, 0);
    test_one_mulsi3(10, 0, 0);
    test_one_mulsi3(0, maxInt(i32), 0);
    test_one_mulsi3(maxInt(i32), 0, 0);
    test_one_mulsi3(0, -1, 0);
    test_one_mulsi3(-1, 0, 0);
    test_one_mulsi3(0, -10, 0);
    test_one_mulsi3(-10, 0, 0);
    test_one_mulsi3(0, minInt(i32), 0);
    test_one_mulsi3(minInt(i32), 0, 0);
    test_one_mulsi3(1, 1, 1);
    test_one_mulsi3(1, 10, 10);
    test_one_mulsi3(10, 1, 10);
    test_one_mulsi3(1, maxInt(i32), maxInt(i32));
    test_one_mulsi3(maxInt(i32), 1, maxInt(i32));
    test_one_mulsi3(1, -1, -1);
    test_one_mulsi3(1, -10, -10);
    test_one_mulsi3(-10, 1, -10);
    test_one_mulsi3(1, minInt(i32), minInt(i32));
    test_one_mulsi3(minInt(i32), 1, minInt(i32));
    test_one_mulsi3(46340, 46340, 2147395600);
    test_one_mulsi3(-46340, 46340, -2147395600);
    test_one_mulsi3(46340, -46340, -2147395600);
    test_one_mulsi3(-46340, -46340, 2147395600);
    test_one_mulsi3(4194303, 8192, @truncate(i32, 34359730176));
    test_one_mulsi3(-4194303, 8192, @truncate(i32, -34359730176));
    test_one_mulsi3(4194303, -8192, @truncate(i32, -34359730176));
    test_one_mulsi3(-4194303, -8192, @truncate(i32, 34359730176));
    test_one_mulsi3(8192, 4194303, @truncate(i32, 34359730176));
    test_one_mulsi3(-8192, 4194303, @truncate(i32, -34359730176));
    test_one_mulsi3(8192, -4194303, @truncate(i32, -34359730176));
    test_one_mulsi3(-8192, -4194303, @truncate(i32, 34359730176));
}

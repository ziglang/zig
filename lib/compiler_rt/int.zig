//! Builtin functions that operate on integer types

const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const common = @import("common.zig");
const udivmod = @import("udivmod.zig").udivmod;
const __divti3 = @import("divti3.zig").__divti3;
const arm = @import("arm.zig");

pub const panic = common.panic;

comptime {
    @export(&__divmodti4, .{ .name = "__divmodti4", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__udivmoddi4, .{ .name = "__udivmoddi4", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__divmoddi4, .{ .name = "__divmoddi4", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_aeabi) {
        @export(&__aeabi_idiv, .{ .name = "__aeabi_idiv", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_uidiv, .{ .name = "__aeabi_uidiv", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__divsi3, .{ .name = "__divsi3", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__udivsi3, .{ .name = "__udivsi3", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__divdi3, .{ .name = "__divdi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__udivdi3, .{ .name = "__udivdi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__modsi3, .{ .name = "__modsi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__moddi3, .{ .name = "__moddi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__umodsi3, .{ .name = "__umodsi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__umoddi3, .{ .name = "__umoddi3", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__divmodsi4, .{ .name = "__divmodsi4", .linkage = common.linkage, .visibility = common.visibility });
    @export(&__udivmodsi4, .{ .name = "__udivmodsi4", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __divmodti4(a: i128, b: i128, rem: *i128) callconv(.C) i128 {
    const d = __divti3(a, b);
    rem.* = a -% (d * b);
    return d;
}

test "test_divmodti4" {
    const cases = [_][4]i128{
        [_]i128{ 0, 1, 0, 0 },
        [_]i128{ 0, -1, 0, 0 },
        [_]i128{ 2, 1, 2, 0 },
        [_]i128{ 2, -1, -2, 0 },
        [_]i128{ -2, 1, -2, 0 },
        [_]i128{ -2, -1, 2, 0 },
        [_]i128{ 7, 5, 1, 2 },
        [_]i128{ -7, 5, -1, -2 },
        [_]i128{ 19, 5, 3, 4 },
        [_]i128{ 19, -5, -3, 4 },
        [_]i128{ @bitCast(@as(u128, 0x80000000000000000000000000000000)), 8, @bitCast(@as(u128, 0xf0000000000000000000000000000000)), 0 },
        [_]i128{ @bitCast(@as(u128, 0x80000000000000000000000000000007)), 8, @bitCast(@as(u128, 0xf0000000000000000000000000000001)), -1 },
    };

    for (cases) |case| {
        try test_one_divmodti4(case[0], case[1], case[2], case[3]);
    }
}

fn test_one_divmodti4(a: i128, b: i128, expected_q: i128, expected_r: i128) !void {
    var r: i128 = undefined;
    const q: i128 = __divmodti4(a, b, &r);
    try testing.expect(q == expected_q and r == expected_r);
}

pub fn __divmoddi4(a: i64, b: i64, rem: *i64) callconv(.C) i64 {
    const d = __divdi3(a, b);
    rem.* = a -% (d * b);
    return d;
}

fn test_one_divmoddi4(a: i64, b: i64, expected_q: i64, expected_r: i64) !void {
    var r: i64 = undefined;
    const q: i64 = __divmoddi4(a, b, &r);
    try testing.expect(q == expected_q and r == expected_r);
}

const cases__divmoddi4 =
    [_][4]i64{
    [_]i64{ 0, 1, 0, 0 },
    [_]i64{ 0, -1, 0, 0 },
    [_]i64{ 2, 1, 2, 0 },
    [_]i64{ 2, -1, -2, 0 },
    [_]i64{ -2, 1, -2, 0 },
    [_]i64{ -2, -1, 2, 0 },
    [_]i64{ 7, 5, 1, 2 },
    [_]i64{ -7, 5, -1, -2 },
    [_]i64{ 19, 5, 3, 4 },
    [_]i64{ 19, -5, -3, 4 },
    [_]i64{ @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 8, @as(i64, @bitCast(@as(u64, 0xf000000000000000))), 0 },
    [_]i64{ @as(i64, @bitCast(@as(u64, 0x8000000000000007))), 8, @as(i64, @bitCast(@as(u64, 0xf000000000000001))), -1 },
};

test "test_divmoddi4" {
    for (cases__divmoddi4) |case| {
        try test_one_divmoddi4(case[0], case[1], case[2], case[3]);
    }
}

fn test_one_aeabi_ldivmod(a: i64, b: i64, expected_q: i64, expected_r: i64) !void {
    const LdivmodRes = extern struct {
        q: i64, // r1:r0
        r: i64, // r3:r2
    };
    const actualIdivmod = @as(*const fn (a: i64, b: i64) callconv(.AAPCS) LdivmodRes, @ptrCast(&arm.__aeabi_ldivmod));
    const arm_res = actualIdivmod(a, b);
    try testing.expectEqual(expected_q, arm_res.q);
    try testing.expectEqual(expected_r, arm_res.r);
}

test "arm.__aeabi_ldivmod" {
    if (!builtin.cpu.arch.isARM()) return error.SkipZigTest;

    for (cases__divmodsi4) |case| {
        try test_one_aeabi_ldivmod(case[0], case[1], case[2], case[3]);
    }
}

pub fn __udivmoddi4(a: u64, b: u64, maybe_rem: ?*u64) callconv(.C) u64 {
    return udivmod(u64, a, b, maybe_rem);
}

test "test_udivmoddi4" {
    _ = @import("udivmoddi4_test.zig");
}

pub fn __divdi3(a: i64, b: i64) callconv(.C) i64 {
    // Set aside the sign of the quotient.
    const sign: u64 = @bitCast((a ^ b) >> 63);
    // Take absolute value of a and b via abs(x) = (x^(x >> 63)) - (x >> 63).
    const abs_a = (a ^ (a >> 63)) -% (a >> 63);
    const abs_b = (b ^ (b >> 63)) -% (b >> 63);
    // Unsigned division
    const res = __udivmoddi4(@bitCast(abs_a), @bitCast(abs_b), null);
    // Apply sign of quotient to result and return.
    return @bitCast((res ^ sign) -% sign);
}

test "test_divdi3" {
    const cases = [_][3]i64{
        [_]i64{ 0, 1, 0 },
        [_]i64{ 0, -1, 0 },
        [_]i64{ 2, 1, 2 },
        [_]i64{ 2, -1, -2 },
        [_]i64{ -2, 1, -2 },
        [_]i64{ -2, -1, 2 },

        [_]i64{ @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 1, @as(i64, @bitCast(@as(u64, 0x8000000000000000))) },
        [_]i64{ @as(i64, @bitCast(@as(u64, 0x8000000000000000))), -1, @as(i64, @bitCast(@as(u64, 0x8000000000000000))) },
        [_]i64{ @as(i64, @bitCast(@as(u64, 0x8000000000000000))), -2, 0x4000000000000000 },
        [_]i64{ @as(i64, @bitCast(@as(u64, 0x8000000000000000))), 2, @as(i64, @bitCast(@as(u64, 0xC000000000000000))) },
    };

    for (cases) |case| {
        try test_one_divdi3(case[0], case[1], case[2]);
    }
}

fn test_one_divdi3(a: i64, b: i64, expected_q: i64) !void {
    const q: i64 = __divdi3(a, b);
    try testing.expect(q == expected_q);
}

pub fn __moddi3(a: i64, b: i64) callconv(.C) i64 {
    // Take absolute value of a and b via abs(x) = (x^(x >> 63)) - (x >> 63).
    const abs_a = (a ^ (a >> 63)) -% (a >> 63);
    const abs_b = (b ^ (b >> 63)) -% (b >> 63);
    // Unsigned division
    var r: u64 = undefined;
    _ = __udivmoddi4(@bitCast(abs_a), @bitCast(abs_b), &r);
    // Apply the sign of the dividend and return.
    return (@as(i64, @bitCast(r)) ^ (a >> 63)) -% (a >> 63);
}

test "test_moddi3" {
    const cases = [_][3]i64{
        [_]i64{ 0, 1, 0 },
        [_]i64{ 0, -1, 0 },
        [_]i64{ 5, 3, 2 },
        [_]i64{ 5, -3, 2 },
        [_]i64{ -5, 3, -2 },
        [_]i64{ -5, -3, -2 },

        [_]i64{ @bitCast(@as(u64, 0x8000000000000000)), 1, 0 },
        [_]i64{ @bitCast(@as(u64, 0x8000000000000000)), -1, 0 },
        [_]i64{ @bitCast(@as(u64, 0x8000000000000000)), 2, 0 },
        [_]i64{ @bitCast(@as(u64, 0x8000000000000000)), -2, 0 },
        [_]i64{ @bitCast(@as(u64, 0x8000000000000000)), 3, -2 },
        [_]i64{ @bitCast(@as(u64, 0x8000000000000000)), -3, -2 },
    };

    for (cases) |case| {
        try test_one_moddi3(case[0], case[1], case[2]);
    }
}

fn test_one_moddi3(a: i64, b: i64, expected_r: i64) !void {
    const r: i64 = __moddi3(a, b);
    try testing.expect(r == expected_r);
}

pub fn __udivdi3(a: u64, b: u64) callconv(.C) u64 {
    return __udivmoddi4(a, b, null);
}

pub fn __umoddi3(a: u64, b: u64) callconv(.C) u64 {
    var r: u64 = undefined;
    _ = __udivmoddi4(a, b, &r);
    return r;
}

test "test_umoddi3" {
    try test_one_umoddi3(0, 1, 0);
    try test_one_umoddi3(2, 1, 0);
    try test_one_umoddi3(0x8000000000000000, 1, 0x0);
    try test_one_umoddi3(0x8000000000000000, 2, 0x0);
    try test_one_umoddi3(0xFFFFFFFFFFFFFFFF, 2, 0x1);
}

fn test_one_umoddi3(a: u64, b: u64, expected_r: u64) !void {
    const r = __umoddi3(a, b);
    try testing.expect(r == expected_r);
}

pub fn __divmodsi4(a: i32, b: i32, rem: *i32) callconv(.C) i32 {
    const d = __divsi3(a, b);
    rem.* = a -% (d * b);
    return d;
}

const cases__divmodsi4 =
    [_][4]i32{
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
    [_]i32{ @bitCast(@as(u32, 0x80000000)), 8, @bitCast(@as(u32, 0xf0000000)), 0 },
    [_]i32{ @bitCast(@as(u32, 0x80000007)), 8, @bitCast(@as(u32, 0xf0000001)), -1 },
};

fn test_one_divmodsi4(a: i32, b: i32, expected_q: i32, expected_r: i32) !void {
    var r: i32 = undefined;
    const q: i32 = __divmodsi4(a, b, &r);
    try testing.expect(q == expected_q and r == expected_r);
}

test "test_divmodsi4" {
    for (cases__divmodsi4) |case| {
        try test_one_divmodsi4(case[0], case[1], case[2], case[3]);
    }
}

fn test_one_aeabi_idivmod(a: i32, b: i32, expected_q: i32, expected_r: i32) !void {
    const IdivmodRes = extern struct {
        q: i32, // r0
        r: i32, // r1
    };
    const actualIdivmod = @as(*const fn (a: i32, b: i32) callconv(.AAPCS) IdivmodRes, @ptrCast(&arm.__aeabi_idivmod));
    const arm_res = actualIdivmod(a, b);
    try testing.expectEqual(expected_q, arm_res.q);
    try testing.expectEqual(expected_r, arm_res.r);
}

test "arm.__aeabi_idivmod" {
    if (!builtin.cpu.arch.isARM()) return error.SkipZigTest;

    for (cases__divmodsi4) |case| {
        try test_one_aeabi_idivmod(case[0], case[1], case[2], case[3]);
    }
}

pub fn __udivmodsi4(a: u32, b: u32, rem: *u32) callconv(.C) u32 {
    const d = __udivsi3(a, b);
    rem.* = @bitCast(@as(i32, @bitCast(a)) -% (@as(i32, @bitCast(d)) * @as(i32, @bitCast(b))));
    return d;
}

pub fn __divsi3(n: i32, d: i32) callconv(.C) i32 {
    return div_i32(n, d);
}

fn __aeabi_idiv(n: i32, d: i32) callconv(.AAPCS) i32 {
    return div_i32(n, d);
}

inline fn div_i32(n: i32, d: i32) i32 {
    // Set aside the sign of the quotient.
    const sign: u32 = @bitCast((n ^ d) >> 31);
    // Take absolute value of a and b via abs(x) = (x^(x >> 31)) - (x >> 31).
    const abs_n = (n ^ (n >> 31)) -% (n >> 31);
    const abs_d = (d ^ (d >> 31)) -% (d >> 31);
    // abs(a) / abs(b)
    const res = @as(u32, @bitCast(abs_n)) / @as(u32, @bitCast(abs_d));
    // Apply sign of quotient to result and return.
    return @bitCast((res ^ sign) -% sign);
}

test "test_divsi3" {
    const cases = [_][3]i32{
        [_]i32{ 0, 1, 0 },
        [_]i32{ 0, -1, 0 },
        [_]i32{ 2, 1, 2 },
        [_]i32{ 2, -1, -2 },
        [_]i32{ -2, 1, -2 },
        [_]i32{ -2, -1, 2 },

        [_]i32{ @bitCast(@as(u32, 0x80000000)), 1, @bitCast(@as(u32, 0x80000000)) },
        [_]i32{ @bitCast(@as(u32, 0x80000000)), -1, @bitCast(@as(u32, 0x80000000)) },
        [_]i32{ @bitCast(@as(u32, 0x80000000)), -2, 0x40000000 },
        [_]i32{ @bitCast(@as(u32, 0x80000000)), 2, @bitCast(@as(u32, 0xC0000000)) },
    };

    for (cases) |case| {
        try test_one_divsi3(case[0], case[1], case[2]);
    }
}

fn test_one_divsi3(a: i32, b: i32, expected_q: i32) !void {
    const q: i32 = __divsi3(a, b);
    try testing.expect(q == expected_q);
}

pub fn __udivsi3(n: u32, d: u32) callconv(.C) u32 {
    return div_u32(n, d);
}

fn __aeabi_uidiv(n: u32, d: u32) callconv(.AAPCS) u32 {
    return div_u32(n, d);
}

inline fn div_u32(n: u32, d: u32) u32 {
    const n_uword_bits: c_uint = 32;
    // special cases
    if (d == 0) return 0; // ?!
    if (n == 0) return 0;
    var sr = @as(c_uint, @bitCast(@as(c_int, @clz(d)) - @as(c_int, @clz(n))));
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
    var q: u32 = n << @intCast(n_uword_bits - sr);
    var r: u32 = n >> @intCast(sr);
    var carry: u32 = 0;
    while (sr > 0) : (sr -= 1) {
        // r:q = ((r:q)  << 1) | carry
        r = (r << 1) | (q >> @intCast(n_uword_bits - 1));
        q = (q << 1) | carry;
        // carry = 0;
        // if (r.all >= d.all)
        // {
        //      r.all -= d.all;
        //      carry = 1;
        // }
        const s = @as(i32, @bitCast(d -% r -% 1)) >> @intCast(n_uword_bits - 1);
        carry = @intCast(s & 1);
        r -= d & @as(u32, @bitCast(s));
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
        try test_one_udivsi3(case[0], case[1], case[2]);
    }
}

fn test_one_udivsi3(a: u32, b: u32, expected_q: u32) !void {
    const q: u32 = __udivsi3(a, b);
    try testing.expect(q == expected_q);
}

pub fn __modsi3(n: i32, d: i32) callconv(.C) i32 {
    return n -% __divsi3(n, d) * d;
}

test "test_modsi3" {
    const cases = [_][3]i32{
        [_]i32{ 0, 1, 0 },
        [_]i32{ 0, -1, 0 },
        [_]i32{ 5, 3, 2 },
        [_]i32{ 5, -3, 2 },
        [_]i32{ -5, 3, -2 },
        [_]i32{ -5, -3, -2 },
        [_]i32{ @bitCast(@as(u32, @intCast(0x80000000))), 1, 0x0 },
        [_]i32{ @bitCast(@as(u32, @intCast(0x80000000))), 2, 0x0 },
        [_]i32{ @bitCast(@as(u32, @intCast(0x80000000))), -2, 0x0 },
        [_]i32{ @bitCast(@as(u32, @intCast(0x80000000))), 3, -2 },
        [_]i32{ @bitCast(@as(u32, @intCast(0x80000000))), -3, -2 },
    };

    for (cases) |case| {
        try test_one_modsi3(case[0], case[1], case[2]);
    }
}

fn test_one_modsi3(a: i32, b: i32, expected_r: i32) !void {
    const r: i32 = __modsi3(a, b);
    try testing.expect(r == expected_r);
}

pub fn __umodsi3(n: u32, d: u32) callconv(.C) u32 {
    return n -% __udivsi3(n, d) * d;
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
        try test_one_umodsi3(case[0], case[1], case[2]);
    }
}

fn test_one_umodsi3(a: u32, b: u32, expected_r: u32) !void {
    const r: u32 = __umodsi3(a, b);
    try testing.expect(r == expected_r);
}

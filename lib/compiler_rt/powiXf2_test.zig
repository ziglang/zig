// ported from https://github.com/llvm-mirror/compiler-rt/blob/release_80/test/builtins/Unit/
// powisf2_test.c, powidf2_test.c, powitf2_test.c, powixf2_test.c
// powihf2 adapted from powisf2 tests

const powiXf2 = @import("powiXf2.zig");
const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const math = std.math;

fn test__powihf2(a: f16, b: i32, expected: f16) !void {
    const result = powiXf2.__powihf2(a, b);
    try testing.expectEqual(expected, result);
}

fn test__powisf2(a: f32, b: i32, expected: f32) !void {
    const result = powiXf2.__powisf2(a, b);
    try testing.expectEqual(expected, result);
}

fn test__powidf2(a: f64, b: i32, expected: f64) !void {
    const result = powiXf2.__powidf2(a, b);
    try testing.expectEqual(expected, result);
}

fn test__powitf2(a: f128, b: i32, expected: f128) !void {
    const result = powiXf2.__powitf2(a, b);
    try testing.expectEqual(expected, result);
}

fn test__powixf2(a: f80, b: i32, expected: f80) !void {
    const result = powiXf2.__powixf2(a, b);
    try testing.expectEqual(expected, result);
}

test "powihf2" {
    const inf_f16 = math.inf(f16);
    try test__powisf2(0, 0, 1);
    try test__powihf2(1, 0, 1);
    try test__powihf2(1.5, 0, 1);
    try test__powihf2(2, 0, 1);
    try test__powihf2(inf_f16, 0, 1);

    try test__powihf2(-0.0, 0, 1);
    try test__powihf2(-1, 0, 1);
    try test__powihf2(-1.5, 0, 1);
    try test__powihf2(-2, 0, 1);
    try test__powihf2(-inf_f16, 0, 1);

    try test__powihf2(0, 1, 0);
    try test__powihf2(0, 2, 0);
    try test__powihf2(0, 3, 0);
    try test__powihf2(0, 4, 0);
    try test__powihf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powihf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 0);

    try test__powihf2(-0.0, 1, -0.0);
    try test__powihf2(-0.0, 2, 0);
    try test__powihf2(-0.0, 3, -0.0);
    try test__powihf2(-0.0, 4, 0);
    try test__powihf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powihf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -0.0);

    try test__powihf2(1, 1, 1);
    try test__powihf2(1, 2, 1);
    try test__powihf2(1, 3, 1);
    try test__powihf2(1, 4, 1);
    try test__powihf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 1);
    try test__powihf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 1);

    try test__powihf2(inf_f16, 1, inf_f16);
    try test__powihf2(inf_f16, 2, inf_f16);
    try test__powihf2(inf_f16, 3, inf_f16);
    try test__powihf2(inf_f16, 4, inf_f16);
    try test__powihf2(inf_f16, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f16);
    try test__powihf2(inf_f16, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), inf_f16);

    try test__powihf2(-inf_f16, 1, -inf_f16);
    try test__powihf2(-inf_f16, 2, inf_f16);
    try test__powihf2(-inf_f16, 3, -inf_f16);
    try test__powihf2(-inf_f16, 4, inf_f16);
    try test__powihf2(-inf_f16, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f16);
    try test__powihf2(-inf_f16, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -inf_f16);
    //
    try test__powihf2(0, -1, inf_f16);
    try test__powihf2(0, -2, inf_f16);
    try test__powihf2(0, -3, inf_f16);
    try test__powihf2(0, -4, inf_f16);
    try test__powihf2(0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f16); // 0 ^ anything = +inf
    try test__powihf2(0, @as(i32, @bitCast(@as(u32, 0x80000001))), inf_f16);
    try test__powihf2(0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f16);

    try test__powihf2(-0.0, -1, -inf_f16);
    try test__powihf2(-0.0, -2, inf_f16);
    try test__powihf2(-0.0, -3, -inf_f16);
    try test__powihf2(-0.0, -4, inf_f16);
    try test__powihf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f16); // -0 ^ anything even = +inf
    try test__powihf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000001))), -inf_f16); // -0 ^ anything odd = -inf
    try test__powihf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f16);

    try test__powihf2(1, -1, 1);
    try test__powihf2(1, -2, 1);
    try test__powihf2(1, -3, 1);
    try test__powihf2(1, -4, 1);
    try test__powihf2(1, @as(i32, @bitCast(@as(u32, 0x80000002))), 1); // 1.0 ^ anything = 1
    try test__powihf2(1, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__powihf2(1, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);

    try test__powihf2(inf_f16, -1, 0);
    try test__powihf2(inf_f16, -2, 0);
    try test__powihf2(inf_f16, -3, 0);
    try test__powihf2(inf_f16, -4, 0);
    try test__powihf2(inf_f16, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powihf2(inf_f16, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__powihf2(inf_f16, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);
    //
    try test__powihf2(-inf_f16, -1, -0.0);
    try test__powihf2(-inf_f16, -2, 0);
    try test__powihf2(-inf_f16, -3, -0.0);
    try test__powihf2(-inf_f16, -4, 0);
    try test__powihf2(-inf_f16, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powihf2(-inf_f16, @as(i32, @bitCast(@as(u32, 0x80000001))), -0.0);
    try test__powihf2(-inf_f16, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powihf2(2, 10, 1024.0);
    try test__powihf2(-2, 10, 1024.0);
    try test__powihf2(2, -10, 1.0 / 1024.0);
    try test__powihf2(-2, -10, 1.0 / 1024.0);

    try test__powihf2(2, 14, 16384.0);
    try test__powihf2(-2, 14, 16384.0);
    try test__powihf2(2, 15, 32768.0);
    try test__powihf2(-2, 15, -32768.0);
    try test__powihf2(2, 16, inf_f16);
    try test__powihf2(-2, 16, inf_f16);

    try test__powihf2(2, -13, 1.0 / 8192.0);
    try test__powihf2(-2, -13, -1.0 / 8192.0);
    try test__powihf2(2, -15, 1.0 / 32768.0);
    try test__powihf2(-2, -15, -1.0 / 32768.0);
    try test__powihf2(2, -16, 0.0); // expected = 0.0 = 1/(-2**16)
    try test__powihf2(-2, -16, 0.0); // expected = 0.0 = 1/(2**16)
}

test "powisf2" {
    const inf_f32 = math.inf(f32);
    try test__powisf2(0, 0, 1);
    try test__powisf2(1, 0, 1);
    try test__powisf2(1.5, 0, 1);
    try test__powisf2(2, 0, 1);
    try test__powisf2(inf_f32, 0, 1);

    try test__powisf2(-0.0, 0, 1);
    try test__powisf2(-1, 0, 1);
    try test__powisf2(-1.5, 0, 1);
    try test__powisf2(-2, 0, 1);
    try test__powisf2(-inf_f32, 0, 1);

    try test__powisf2(0, 1, 0);
    try test__powisf2(0, 2, 0);
    try test__powisf2(0, 3, 0);
    try test__powisf2(0, 4, 0);
    try test__powisf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powisf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 0);

    try test__powisf2(-0.0, 1, -0.0);
    try test__powisf2(-0.0, 2, 0);
    try test__powisf2(-0.0, 3, -0.0);
    try test__powisf2(-0.0, 4, 0);
    try test__powisf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powisf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -0.0);

    try test__powisf2(1, 1, 1);
    try test__powisf2(1, 2, 1);
    try test__powisf2(1, 3, 1);
    try test__powisf2(1, 4, 1);
    try test__powisf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 1);
    try test__powisf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 1);

    try test__powisf2(inf_f32, 1, inf_f32);
    try test__powisf2(inf_f32, 2, inf_f32);
    try test__powisf2(inf_f32, 3, inf_f32);
    try test__powisf2(inf_f32, 4, inf_f32);
    try test__powisf2(inf_f32, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f32);
    try test__powisf2(inf_f32, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), inf_f32);

    try test__powisf2(-inf_f32, 1, -inf_f32);
    try test__powisf2(-inf_f32, 2, inf_f32);
    try test__powisf2(-inf_f32, 3, -inf_f32);
    try test__powisf2(-inf_f32, 4, inf_f32);
    try test__powisf2(-inf_f32, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f32);
    try test__powisf2(-inf_f32, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -inf_f32);

    try test__powisf2(0, -1, inf_f32);
    try test__powisf2(0, -2, inf_f32);
    try test__powisf2(0, -3, inf_f32);
    try test__powisf2(0, -4, inf_f32);
    try test__powisf2(0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f32);
    try test__powisf2(0, @as(i32, @bitCast(@as(u32, 0x80000001))), inf_f32);
    try test__powisf2(0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f32);

    try test__powisf2(-0.0, -1, -inf_f32);
    try test__powisf2(-0.0, -2, inf_f32);
    try test__powisf2(-0.0, -3, -inf_f32);
    try test__powisf2(-0.0, -4, inf_f32);
    try test__powisf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f32);
    try test__powisf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000001))), -inf_f32);
    try test__powisf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f32);

    try test__powisf2(1, -1, 1);
    try test__powisf2(1, -2, 1);
    try test__powisf2(1, -3, 1);
    try test__powisf2(1, -4, 1);
    try test__powisf2(1, @as(i32, @bitCast(@as(u32, 0x80000002))), 1);
    try test__powisf2(1, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__powisf2(1, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);

    try test__powisf2(inf_f32, -1, 0);
    try test__powisf2(inf_f32, -2, 0);
    try test__powisf2(inf_f32, -3, 0);
    try test__powisf2(inf_f32, -4, 0);
    try test__powisf2(inf_f32, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powisf2(inf_f32, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__powisf2(inf_f32, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powisf2(-inf_f32, -1, -0.0);
    try test__powisf2(-inf_f32, -2, 0);
    try test__powisf2(-inf_f32, -3, -0.0);
    try test__powisf2(-inf_f32, -4, 0);
    try test__powisf2(-inf_f32, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powisf2(-inf_f32, @as(i32, @bitCast(@as(u32, 0x80000001))), -0.0);
    try test__powisf2(-inf_f32, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powisf2(2.0, 10, 1024.0);
    try test__powisf2(-2, 10, 1024.0);
    try test__powisf2(2, -10, 1.0 / 1024.0);
    try test__powisf2(-2, -10, 1.0 / 1024.0);
    //
    try test__powisf2(2, 19, 524288.0);
    try test__powisf2(-2, 19, -524288.0);
    try test__powisf2(2, -19, 1.0 / 524288.0);
    try test__powisf2(-2, -19, -1.0 / 524288.0);

    try test__powisf2(2, 31, 2147483648.0);
    try test__powisf2(-2, 31, -2147483648.0);
    try test__powisf2(2, -31, 1.0 / 2147483648.0);
    try test__powisf2(-2, -31, -1.0 / 2147483648.0);
}

test "powidf2" {
    const inf_f64 = math.inf(f64);
    try test__powidf2(0, 0, 1);
    try test__powidf2(1, 0, 1);
    try test__powidf2(1.5, 0, 1);
    try test__powidf2(2, 0, 1);
    try test__powidf2(inf_f64, 0, 1);

    try test__powidf2(-0.0, 0, 1);
    try test__powidf2(-1, 0, 1);
    try test__powidf2(-1.5, 0, 1);
    try test__powidf2(-2, 0, 1);
    try test__powidf2(-inf_f64, 0, 1);

    try test__powidf2(0, 1, 0);
    try test__powidf2(0, 2, 0);
    try test__powidf2(0, 3, 0);
    try test__powidf2(0, 4, 0);
    try test__powidf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powidf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 0);

    try test__powidf2(-0.0, 1, -0.0);
    try test__powidf2(-0.0, 2, 0);
    try test__powidf2(-0.0, 3, -0.0);
    try test__powidf2(-0.0, 4, 0);
    try test__powidf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powidf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -0.0);

    try test__powidf2(1, 1, 1);
    try test__powidf2(1, 2, 1);
    try test__powidf2(1, 3, 1);
    try test__powidf2(1, 4, 1);
    try test__powidf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 1);
    try test__powidf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 1);

    try test__powidf2(inf_f64, 1, inf_f64);
    try test__powidf2(inf_f64, 2, inf_f64);
    try test__powidf2(inf_f64, 3, inf_f64);
    try test__powidf2(inf_f64, 4, inf_f64);
    try test__powidf2(inf_f64, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f64);
    try test__powidf2(inf_f64, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), inf_f64);

    try test__powidf2(-inf_f64, 1, -inf_f64);
    try test__powidf2(-inf_f64, 2, inf_f64);
    try test__powidf2(-inf_f64, 3, -inf_f64);
    try test__powidf2(-inf_f64, 4, inf_f64);
    try test__powidf2(-inf_f64, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f64);
    try test__powidf2(-inf_f64, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -inf_f64);

    try test__powidf2(0, -1, inf_f64);
    try test__powidf2(0, -2, inf_f64);
    try test__powidf2(0, -3, inf_f64);
    try test__powidf2(0, -4, inf_f64);
    try test__powidf2(0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f64);
    try test__powidf2(0, @as(i32, @bitCast(@as(u32, 0x80000001))), inf_f64);
    try test__powidf2(0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f64);

    try test__powidf2(-0.0, -1, -inf_f64);
    try test__powidf2(-0.0, -2, inf_f64);
    try test__powidf2(-0.0, -3, -inf_f64);
    try test__powidf2(-0.0, -4, inf_f64);
    try test__powidf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f64);
    try test__powidf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000001))), -inf_f64);
    try test__powidf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f64);

    try test__powidf2(1, -1, 1);
    try test__powidf2(1, -2, 1);
    try test__powidf2(1, -3, 1);
    try test__powidf2(1, -4, 1);
    try test__powidf2(1, @as(i32, @bitCast(@as(u32, 0x80000002))), 1);
    try test__powidf2(1, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__powidf2(1, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);

    try test__powidf2(inf_f64, -1, 0);
    try test__powidf2(inf_f64, -2, 0);
    try test__powidf2(inf_f64, -3, 0);
    try test__powidf2(inf_f64, -4, 0);
    try test__powidf2(inf_f64, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powidf2(inf_f64, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__powidf2(inf_f64, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powidf2(-inf_f64, -1, -0.0);
    try test__powidf2(-inf_f64, -2, 0);
    try test__powidf2(-inf_f64, -3, -0.0);
    try test__powidf2(-inf_f64, -4, 0);
    try test__powidf2(-inf_f64, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powidf2(-inf_f64, @as(i32, @bitCast(@as(u32, 0x80000001))), -0.0);
    try test__powidf2(-inf_f64, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powidf2(2, 10, 1024.0);
    try test__powidf2(-2, 10, 1024.0);
    try test__powidf2(2, -10, 1.0 / 1024.0);
    try test__powidf2(-2, -10, 1.0 / 1024.0);

    try test__powidf2(2, 19, 524288.0);
    try test__powidf2(-2, 19, -524288.0);
    try test__powidf2(2, -19, 1.0 / 524288.0);
    try test__powidf2(-2, -19, -1.0 / 524288.0);

    try test__powidf2(2, 31, 2147483648.0);
    try test__powidf2(-2, 31, -2147483648.0);
    try test__powidf2(2, -31, 1.0 / 2147483648.0);
    try test__powidf2(-2, -31, -1.0 / 2147483648.0);
}

test "powitf2" {
    const inf_f128 = math.inf(f128);
    try test__powitf2(0, 0, 1);
    try test__powitf2(1, 0, 1);
    try test__powitf2(1.5, 0, 1);
    try test__powitf2(2, 0, 1);
    try test__powitf2(inf_f128, 0, 1);

    try test__powitf2(-0.0, 0, 1);
    try test__powitf2(-1, 0, 1);
    try test__powitf2(-1.5, 0, 1);
    try test__powitf2(-2, 0, 1);
    try test__powitf2(-inf_f128, 0, 1);

    try test__powitf2(0, 1, 0);
    try test__powitf2(0, 2, 0);
    try test__powitf2(0, 3, 0);
    try test__powitf2(0, 4, 0);
    try test__powitf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powitf2(0, 0x7FFFFFFF, 0);

    try test__powitf2(-0.0, 1, -0.0);
    try test__powitf2(-0.0, 2, 0);
    try test__powitf2(-0.0, 3, -0.0);
    try test__powitf2(-0.0, 4, 0);
    try test__powitf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powitf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -0.0);

    try test__powitf2(1, 1, 1);
    try test__powitf2(1, 2, 1);
    try test__powitf2(1, 3, 1);
    try test__powitf2(1, 4, 1);
    try test__powitf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 1);
    try test__powitf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 1);

    try test__powitf2(inf_f128, 1, inf_f128);
    try test__powitf2(inf_f128, 2, inf_f128);
    try test__powitf2(inf_f128, 3, inf_f128);
    try test__powitf2(inf_f128, 4, inf_f128);
    try test__powitf2(inf_f128, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f128);
    try test__powitf2(inf_f128, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), inf_f128);

    try test__powitf2(-inf_f128, 1, -inf_f128);
    try test__powitf2(-inf_f128, 2, inf_f128);
    try test__powitf2(-inf_f128, 3, -inf_f128);
    try test__powitf2(-inf_f128, 4, inf_f128);
    try test__powitf2(-inf_f128, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f128);
    try test__powitf2(-inf_f128, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -inf_f128);

    try test__powitf2(0, -1, inf_f128);
    try test__powitf2(0, -2, inf_f128);
    try test__powitf2(0, -3, inf_f128);
    try test__powitf2(0, -4, inf_f128);
    try test__powitf2(0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f128);
    try test__powitf2(0, @as(i32, @bitCast(@as(u32, 0x80000001))), inf_f128);
    try test__powitf2(0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f128);

    try test__powitf2(-0.0, -1, -inf_f128);
    try test__powitf2(-0.0, -2, inf_f128);
    try test__powitf2(-0.0, -3, -inf_f128);
    try test__powitf2(-0.0, -4, inf_f128);
    try test__powitf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f128);
    try test__powitf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000001))), -inf_f128);
    try test__powitf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f128);

    try test__powitf2(1, -1, 1);
    try test__powitf2(1, -2, 1);
    try test__powitf2(1, -3, 1);
    try test__powitf2(1, -4, 1);
    try test__powitf2(1, @as(i32, @bitCast(@as(u32, 0x80000002))), 1);
    try test__powitf2(1, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__powitf2(1, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);

    try test__powitf2(inf_f128, -1, 0);
    try test__powitf2(inf_f128, -2, 0);
    try test__powitf2(inf_f128, -3, 0);
    try test__powitf2(inf_f128, -4, 0);
    try test__powitf2(inf_f128, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powitf2(inf_f128, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__powitf2(inf_f128, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powitf2(-inf_f128, -1, -0.0);
    try test__powitf2(-inf_f128, -2, 0);
    try test__powitf2(-inf_f128, -3, -0.0);
    try test__powitf2(-inf_f128, -4, 0);
    try test__powitf2(-inf_f128, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powitf2(-inf_f128, @as(i32, @bitCast(@as(u32, 0x80000001))), -0.0);
    try test__powitf2(-inf_f128, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powitf2(2, 10, 1024.0);
    try test__powitf2(-2, 10, 1024.0);
    try test__powitf2(2, -10, 1.0 / 1024.0);
    try test__powitf2(-2, -10, 1.0 / 1024.0);

    try test__powitf2(2, 19, 524288.0);
    try test__powitf2(-2, 19, -524288.0);
    try test__powitf2(2, -19, 1.0 / 524288.0);
    try test__powitf2(-2, -19, -1.0 / 524288.0);

    try test__powitf2(2, 31, 2147483648.0);
    try test__powitf2(-2, 31, -2147483648.0);
    try test__powitf2(2, -31, 1.0 / 2147483648.0);
    try test__powitf2(-2, -31, -1.0 / 2147483648.0);
}

test "powixf2" {
    const inf_f80 = math.inf(f80);
    try test__powixf2(0, 0, 1);
    try test__powixf2(1, 0, 1);
    try test__powixf2(1.5, 0, 1);
    try test__powixf2(2, 0, 1);
    try test__powixf2(inf_f80, 0, 1);

    try test__powixf2(-0.0, 0, 1);
    try test__powixf2(-1, 0, 1);
    try test__powixf2(-1.5, 0, 1);
    try test__powixf2(-2, 0, 1);
    try test__powixf2(-inf_f80, 0, 1);

    try test__powixf2(0, 1, 0);
    try test__powixf2(0, 2, 0);
    try test__powixf2(0, 3, 0);
    try test__powixf2(0, 4, 0);
    try test__powixf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powixf2(0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 0);

    try test__powixf2(-0.0, 1, -0.0);
    try test__powixf2(-0.0, 2, 0);
    try test__powixf2(-0.0, 3, -0.0);
    try test__powixf2(-0.0, 4, 0);
    try test__powixf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 0);
    try test__powixf2(-0.0, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -0.0);

    try test__powixf2(1, 1, 1);
    try test__powixf2(1, 2, 1);
    try test__powixf2(1, 3, 1);
    try test__powixf2(1, 4, 1);
    try test__powixf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), 1);
    try test__powixf2(1, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), 1);

    try test__powixf2(inf_f80, 1, inf_f80);
    try test__powixf2(inf_f80, 2, inf_f80);
    try test__powixf2(inf_f80, 3, inf_f80);
    try test__powixf2(inf_f80, 4, inf_f80);
    try test__powixf2(inf_f80, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f80);
    try test__powixf2(inf_f80, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), inf_f80);

    try test__powixf2(-inf_f80, 1, -inf_f80);
    try test__powixf2(-inf_f80, 2, inf_f80);
    try test__powixf2(-inf_f80, 3, -inf_f80);
    try test__powixf2(-inf_f80, 4, inf_f80);
    try test__powixf2(-inf_f80, @as(i32, @bitCast(@as(u32, 0x7FFFFFFE))), inf_f80);
    try test__powixf2(-inf_f80, @as(i32, @bitCast(@as(u32, 0x7FFFFFFF))), -inf_f80);

    try test__powixf2(0, -1, inf_f80);
    try test__powixf2(0, -2, inf_f80);
    try test__powixf2(0, -3, inf_f80);
    try test__powixf2(0, -4, inf_f80);
    try test__powixf2(0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f80);
    try test__powixf2(0, @as(i32, @bitCast(@as(u32, 0x80000001))), inf_f80);
    try test__powixf2(0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f80);

    try test__powixf2(-0.0, -1, -inf_f80);
    try test__powixf2(-0.0, -2, inf_f80);
    try test__powixf2(-0.0, -3, -inf_f80);
    try test__powixf2(-0.0, -4, inf_f80);
    try test__powixf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000002))), inf_f80);
    try test__powixf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000001))), -inf_f80);
    try test__powixf2(-0.0, @as(i32, @bitCast(@as(u32, 0x80000000))), inf_f80);

    try test__powixf2(1, -1, 1);
    try test__powixf2(1, -2, 1);
    try test__powixf2(1, -3, 1);
    try test__powixf2(1, -4, 1);
    try test__powixf2(1, @as(i32, @bitCast(@as(u32, 0x80000002))), 1);
    try test__powixf2(1, @as(i32, @bitCast(@as(u32, 0x80000001))), 1);
    try test__powixf2(1, @as(i32, @bitCast(@as(u32, 0x80000000))), 1);

    try test__powixf2(inf_f80, -1, 0);
    try test__powixf2(inf_f80, -2, 0);
    try test__powixf2(inf_f80, -3, 0);
    try test__powixf2(inf_f80, -4, 0);
    try test__powixf2(inf_f80, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powixf2(inf_f80, @as(i32, @bitCast(@as(u32, 0x80000001))), 0);
    try test__powixf2(inf_f80, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powixf2(-inf_f80, -1, -0.0);
    try test__powixf2(-inf_f80, -2, 0);
    try test__powixf2(-inf_f80, -3, -0.0);
    try test__powixf2(-inf_f80, -4, 0);
    try test__powixf2(-inf_f80, @as(i32, @bitCast(@as(u32, 0x80000002))), 0);
    try test__powixf2(-inf_f80, @as(i32, @bitCast(@as(u32, 0x80000001))), -0.0);
    try test__powixf2(-inf_f80, @as(i32, @bitCast(@as(u32, 0x80000000))), 0);

    try test__powixf2(2, 10, 1024.0);
    try test__powixf2(-2, 10, 1024.0);
    try test__powixf2(2, -10, 1.0 / 1024.0);
    try test__powixf2(-2, -10, 1.0 / 1024.0);

    try test__powixf2(2, 19, 524288.0);
    try test__powixf2(-2, 19, -524288.0);
    try test__powixf2(2, -19, 1.0 / 524288.0);
    try test__powixf2(-2, -19, -1.0 / 524288.0);

    try test__powixf2(2, 31, 2147483648.0);
    try test__powixf2(-2, 31, -2147483648.0);
    try test__powixf2(2, -31, 1.0 / 2147483648.0);
    try test__powixf2(-2, -31, -1.0 / 2147483648.0);
}

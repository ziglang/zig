const is_test = @import("builtin").is_test;
const std = @import("std");
const math = std.math;
const testing = std.testing;
const warn = std.debug.warn;

const fixint = @import("fixint.zig").fixint;

fn test__fixint(comptime fp_t: type, comptime fixint_t: type, a: fp_t, expected: fixint_t) !void {
    const x = fixint(fp_t, fixint_t, a);
    //warn("a={} x={}:{x} expected={}:{x})\n", .{a, x, x, expected, expected});
    try testing.expect(x == expected);
}

test "fixint.i1" {
    try test__fixint(f32, i1, -math.inf_f32, -1);
    try test__fixint(f32, i1, -math.f32_max, -1);
    try test__fixint(f32, i1, -2.0, -1);
    try test__fixint(f32, i1, -1.1, -1);
    try test__fixint(f32, i1, -1.0, -1);
    try test__fixint(f32, i1, -0.9, 0);
    try test__fixint(f32, i1, -0.1, 0);
    try test__fixint(f32, i1, -math.f32_min, 0);
    try test__fixint(f32, i1, -0.0, 0);
    try test__fixint(f32, i1, 0.0, 0);
    try test__fixint(f32, i1, math.f32_min, 0);
    try test__fixint(f32, i1, 0.1, 0);
    try test__fixint(f32, i1, 0.9, 0);
    try test__fixint(f32, i1, 1.0, 0);
    try test__fixint(f32, i1, 2.0, 0);
    try test__fixint(f32, i1, math.f32_max, 0);
    try test__fixint(f32, i1, math.inf_f32, 0);
}

test "fixint.i2" {
    try test__fixint(f32, i2, -math.inf_f32, -2);
    try test__fixint(f32, i2, -math.f32_max, -2);
    try test__fixint(f32, i2, -2.0, -2);
    try test__fixint(f32, i2, -1.9, -1);
    try test__fixint(f32, i2, -1.1, -1);
    try test__fixint(f32, i2, -1.0, -1);
    try test__fixint(f32, i2, -0.9, 0);
    try test__fixint(f32, i2, -0.1, 0);
    try test__fixint(f32, i2, -math.f32_min, 0);
    try test__fixint(f32, i2, -0.0, 0);
    try test__fixint(f32, i2, 0.0, 0);
    try test__fixint(f32, i2, math.f32_min, 0);
    try test__fixint(f32, i2, 0.1, 0);
    try test__fixint(f32, i2, 0.9, 0);
    try test__fixint(f32, i2, 1.0, 1);
    try test__fixint(f32, i2, 2.0, 1);
    try test__fixint(f32, i2, math.f32_max, 1);
    try test__fixint(f32, i2, math.inf_f32, 1);
}

test "fixint.i3" {
    try test__fixint(f32, i3, -math.inf_f32, -4);
    try test__fixint(f32, i3, -math.f32_max, -4);
    try test__fixint(f32, i3, -4.0, -4);
    try test__fixint(f32, i3, -3.0, -3);
    try test__fixint(f32, i3, -2.0, -2);
    try test__fixint(f32, i3, -1.9, -1);
    try test__fixint(f32, i3, -1.1, -1);
    try test__fixint(f32, i3, -1.0, -1);
    try test__fixint(f32, i3, -0.9, 0);
    try test__fixint(f32, i3, -0.1, 0);
    try test__fixint(f32, i3, -math.f32_min, 0);
    try test__fixint(f32, i3, -0.0, 0);
    try test__fixint(f32, i3, 0.0, 0);
    try test__fixint(f32, i3, math.f32_min, 0);
    try test__fixint(f32, i3, 0.1, 0);
    try test__fixint(f32, i3, 0.9, 0);
    try test__fixint(f32, i3, 1.0, 1);
    try test__fixint(f32, i3, 2.0, 2);
    try test__fixint(f32, i3, 3.0, 3);
    try test__fixint(f32, i3, 4.0, 3);
    try test__fixint(f32, i3, math.f32_max, 3);
    try test__fixint(f32, i3, math.inf_f32, 3);
}

test "fixint.i32" {
    try test__fixint(f64, i32, -math.inf_f64, math.minInt(i32));
    try test__fixint(f64, i32, -math.f64_max, math.minInt(i32));
    try test__fixint(f64, i32, @as(f64, math.minInt(i32)), math.minInt(i32));
    try test__fixint(f64, i32, @as(f64, math.minInt(i32)) + 1, math.minInt(i32) + 1);
    try test__fixint(f64, i32, -2.0, -2);
    try test__fixint(f64, i32, -1.9, -1);
    try test__fixint(f64, i32, -1.1, -1);
    try test__fixint(f64, i32, -1.0, -1);
    try test__fixint(f64, i32, -0.9, 0);
    try test__fixint(f64, i32, -0.1, 0);
    try test__fixint(f64, i32, -math.f32_min, 0);
    try test__fixint(f64, i32, -0.0, 0);
    try test__fixint(f64, i32, 0.0, 0);
    try test__fixint(f64, i32, math.f32_min, 0);
    try test__fixint(f64, i32, 0.1, 0);
    try test__fixint(f64, i32, 0.9, 0);
    try test__fixint(f64, i32, 1.0, 1);
    try test__fixint(f64, i32, @as(f64, math.maxInt(i32)) - 1, math.maxInt(i32) - 1);
    try test__fixint(f64, i32, @as(f64, math.maxInt(i32)), math.maxInt(i32));
    try test__fixint(f64, i32, math.f64_max, math.maxInt(i32));
    try test__fixint(f64, i32, math.inf_f64, math.maxInt(i32));
}

test "fixint.i64" {
    try test__fixint(f64, i64, -math.inf_f64, math.minInt(i64));
    try test__fixint(f64, i64, -math.f64_max, math.minInt(i64));
    try test__fixint(f64, i64, @as(f64, math.minInt(i64)), math.minInt(i64));
    try test__fixint(f64, i64, @as(f64, math.minInt(i64)) + 1, math.minInt(i64));
    try test__fixint(f64, i64, @as(f64, math.minInt(i64) / 2), math.minInt(i64) / 2);
    try test__fixint(f64, i64, -2.0, -2);
    try test__fixint(f64, i64, -1.9, -1);
    try test__fixint(f64, i64, -1.1, -1);
    try test__fixint(f64, i64, -1.0, -1);
    try test__fixint(f64, i64, -0.9, 0);
    try test__fixint(f64, i64, -0.1, 0);
    try test__fixint(f64, i64, -math.f32_min, 0);
    try test__fixint(f64, i64, -0.0, 0);
    try test__fixint(f64, i64, 0.0, 0);
    try test__fixint(f64, i64, math.f32_min, 0);
    try test__fixint(f64, i64, 0.1, 0);
    try test__fixint(f64, i64, 0.9, 0);
    try test__fixint(f64, i64, 1.0, 1);
    try test__fixint(f64, i64, @as(f64, math.maxInt(i64)) - 1, math.maxInt(i64));
    try test__fixint(f64, i64, @as(f64, math.maxInt(i64)), math.maxInt(i64));
    try test__fixint(f64, i64, math.f64_max, math.maxInt(i64));
    try test__fixint(f64, i64, math.inf_f64, math.maxInt(i64));
}

test "fixint.i128" {
    try test__fixint(f64, i128, -math.inf_f64, math.minInt(i128));
    try test__fixint(f64, i128, -math.f64_max, math.minInt(i128));
    try test__fixint(f64, i128, @as(f64, math.minInt(i128)), math.minInt(i128));
    try test__fixint(f64, i128, @as(f64, math.minInt(i128)) + 1, math.minInt(i128));
    try test__fixint(f64, i128, -2.0, -2);
    try test__fixint(f64, i128, -1.9, -1);
    try test__fixint(f64, i128, -1.1, -1);
    try test__fixint(f64, i128, -1.0, -1);
    try test__fixint(f64, i128, -0.9, 0);
    try test__fixint(f64, i128, -0.1, 0);
    try test__fixint(f64, i128, -math.f32_min, 0);
    try test__fixint(f64, i128, -0.0, 0);
    try test__fixint(f64, i128, 0.0, 0);
    try test__fixint(f64, i128, math.f32_min, 0);
    try test__fixint(f64, i128, 0.1, 0);
    try test__fixint(f64, i128, 0.9, 0);
    try test__fixint(f64, i128, 1.0, 1);
    try test__fixint(f64, i128, @as(f64, math.maxInt(i128)) - 1, math.maxInt(i128));
    try test__fixint(f64, i128, @as(f64, math.maxInt(i128)), math.maxInt(i128));
    try test__fixint(f64, i128, math.f64_max, math.maxInt(i128));
    try test__fixint(f64, i128, math.inf_f64, math.maxInt(i128));
}

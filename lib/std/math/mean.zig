//! Arithmetic mean (https://mathworld.wolfram.com/ArithmeticMean.html)
const std = @import("std");
const math = std.math;
const testing = std.testing;

const max_int_bits = 65535;

/// Computes the mean (average) of a slice of items of type `T`.
/// The type `T` must be either a floating point type or an integer type.
/// Avoids overflow by using a wider intermediate type for the sum.
///
/// Floating point type f128 could still overflow to infinity. You need to handle that case separately.
pub fn mean(comptime T: type, items: []const T) T {
    std.debug.assert(items.len > 0);
    const info = @typeInfo(T);
    return switch (info) {
        .float => float(T, items),
        .int => int(T, items),
        else => @compileError("T must be float or integer, found " ++ @typeName(T)),
    };
}

fn float(comptime T: type, items: []const T) T {
    const info = @typeInfo(T);
    const Wider: type = switch (info.float.bits) {
        16 => f32,
        32 => f64,
        64 => f128,
        80 => f128,
        128 => f128,
        else => @compileError("unknown floating point type " ++ @typeName(T)),
    };
    var sum: Wider = 0;
    for (items) |item| {
        sum += @as(Wider, item);
    }
    const len_wide: Wider = @floatFromInt(items.len);
    const mean_wide: Wider = sum / len_wide;
    return @floatCast(mean_wide);
}

fn int(comptime T: type, items: []const T) T {
    const info = @typeInfo(T);
    const sign = info.int.signedness;
    const bits = info.int.bits;
    const usize_bits = @bitSizeOf(usize);
    const Wider: type = switch (max_int_bits - usize_bits >= bits) {
        true => @Type(.{ .int = .{ .signedness = sign, .bits = bits + usize_bits } }),
        false => @compileError("Calculation can overflow for type " ++ @typeName(T)),
    };
    var sum: Wider = 0;
    for (items) |item| {
        sum += @as(Wider, item);
    }
    const len_wide: Wider = @as(Wider, items.len);
    const mean_wide: Wider = @divFloor(sum, len_wide);
    return @intCast(mean_wide);
}

test "single element returns itself for u16" {
    const items = &[_]u16{42};
    try testing.expectEqual(@as(u16, 42), mean(u16, items));
}

test "single element returns itself for f32" {
    const items = &[_]f32{3.14};
    try testing.expectEqual(@as(f32, 3.14), mean(f32, items));
}

test "average for u8" {
    const items = &[_]u8{ 1, 2, 4 };
    try testing.expectEqual(@as(u8, 2), mean(u8, items));
}

test "average for i16 with negative values" {
    const items = &[_]i16{ -5, 3, 1 };
    try testing.expectEqual(@as(i16, -1), mean(i16, items));
}

test "average for f64" {
    const items = &[_]f64{ 1.0, 2.0, 9.0 };
    try testing.expectEqual(@as(f64, 4.0), mean(f64, items));
}

test "average for f16" {
    const items = &[_]f16{ 1.0, 2.0 };
    try testing.expectEqual(@as(f16, 1.5), mean(f16, items));
}

test "average for f128 with large precision" {
    const eps = math.floatEps(f128);
    const items = &[_]f128{ 0.1, 0.2, 0.3 };
    try testing.expectApproxEqAbs(@as(f128, 0.2), mean(f128, items), eps);
}

test "edge case max values for u8 to test sum overflow prevention" {
    const items = &[_]u8{ 255, 255, 255 };
    try testing.expectEqual(@as(u8, 255), mean(u8, items));
}

test "edge case min values for i8 to test sum underflow prevention" {
    const items = &[_]i8{ -128, -128 };
    try testing.expectEqual(@as(i8, -128), mean(i8, items));
}

test "edge case max values for f16 to test sum overflow prevention" {
    const items = &[_]f16{math.floatMax(f16)} ** 100;
    const expected: f16 = math.floatMax(f16);
    try testing.expectEqual(expected, mean(f16, items));
}

test "edge case floatMin for f32" {
    const items = &[_]f32{math.floatMin(f32)} ** 100;
    const expected: f32 = math.floatMin(f32);
    try testing.expectEqual(expected, mean(f32, items));
}

test "slice from the middle of an array" {
    const items = &[_]u128{ 100, 11, 12, 18, 500 };
    const slice = items[1..4];
    try testing.expectEqual(@as(u128, 13), mean(u128, slice));
}

test "average for almost u65535" {
    if (true) {
        // https://github.com/llvm/llvm-project/issues/96488
        return error.SkipZigTest;
    }
    const T = @Type(.{ .int = .{ .signedness = .unsigned, .bits = max_int_bits - @bitSizeOf(usize) } });
    const items = &[_]T{ 10, 100, 1000, 10000, 100000 };
    try testing.expectEqual(@as(T, 22222), mean(T, items));
}

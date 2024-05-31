const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns whether x is positive zero.
pub inline fn isPositiveZero(x: anytype) bool {
    const T = @TypeOf(x);
    const bit_count = @typeInfo(T).Float.bits;
    const TBits = std.meta.Int(.unsigned, bit_count);
    return @as(TBits, @bitCast(x)) == @as(TBits, 0);
}

/// Returns whether x is negative zero.
pub inline fn isNegativeZero(x: anytype) bool {
    const T = @TypeOf(x);
    const bit_count = @typeInfo(T).Float.bits;
    const TBits = std.meta.Int(.unsigned, bit_count);
    return @as(TBits, @bitCast(x)) == @as(TBits, 1) << (bit_count - 1);
}

test isPositiveZero {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try expect(isPositiveZero(@as(T, 0.0)));
        try expect(!isPositiveZero(@as(T, -0.0)));
        try expect(!isPositiveZero(math.float.min(T)));
        try expect(!isPositiveZero(math.float.max(T)));
        try expect(!isPositiveZero(math.float.inf(T)));
        try expect(!isPositiveZero(-math.float.inf(T)));
    }
}

test isNegativeZero {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try expect(isNegativeZero(@as(T, -0.0)));
        try expect(!isNegativeZero(@as(T, 0.0)));
        try expect(!isNegativeZero(math.float.min(T)));
        try expect(!isNegativeZero(math.float.max(T)));
        try expect(!isNegativeZero(math.float.inf(T)));
        try expect(!isNegativeZero(-math.float.inf(T)));
    }
}

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns whether x is an infinity, ignoring sign.
pub inline fn isInf(x: anytype) bool {
    const T = @TypeOf(x);
    const TBits = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
    const remove_sign = ~@as(TBits, 0) >> 1;
    return @as(TBits, @bitCast(x)) & remove_sign == @as(TBits, @bitCast(math.inf(T)));
}

/// Returns whether x is an infinity with a positive sign.
pub inline fn isPositiveInf(x: anytype) bool {
    return x == math.inf(@TypeOf(x));
}

/// Returns whether x is an infinity with a negative sign.
pub inline fn isNegativeInf(x: anytype) bool {
    return x == -math.inf(@TypeOf(x));
}

test isInf {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try expect(!isInf(@as(T, 0.0)));
        try expect(!isInf(@as(T, -0.0)));
        try expect(isInf(math.inf(T)));
        try expect(isInf(-math.inf(T)));
        try expect(!isInf(math.nan(T)));
        try expect(!isInf(-math.nan(T)));
    }
}

test isPositiveInf {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try expect(!isPositiveInf(@as(T, 0.0)));
        try expect(!isPositiveInf(@as(T, -0.0)));
        try expect(isPositiveInf(math.inf(T)));
        try expect(!isPositiveInf(-math.inf(T)));
        try expect(!isInf(math.nan(T)));
        try expect(!isInf(-math.nan(T)));
    }
}

test isNegativeInf {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try expect(!isNegativeInf(@as(T, 0.0)));
        try expect(!isNegativeInf(@as(T, -0.0)));
        try expect(!isNegativeInf(math.inf(T)));
        try expect(isNegativeInf(-math.inf(T)));
        try expect(!isInf(math.nan(T)));
        try expect(!isInf(-math.nan(T)));
    }
}

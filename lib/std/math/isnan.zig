const std = @import("../std.zig");
const math = std.math;
const meta = std.meta;
const expect = std.testing.expect;

/// Returns whether x is a NaN.
pub fn isNan(x: anytype) bool {
    return x != x;
}

/// Returns whether x is a signalling NaN.
pub fn isSignalNan(x: anytype) bool {
    const T = @TypeOf(x);
    const U = meta.Int(.unsigned, @bitSizeOf(T));
    const signal_bit_mask = 1 << (math.floatFractionalBits(T) - 1);
    return isNan(x) and (@as(U, @bitCast(x)) & signal_bit_mask == 0);
}

test "math.isNan" {
    inline for ([_]type{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        try expect(isNan(math.nan(T)));
        try expect(isNan(-math.nan(T)));
        try expect(isNan(math.snan(T)));
        try expect(!isNan(@as(T, 1.0)));
        try expect(!isNan(@as(T, math.inf(T))));
    }
}

test "math.isSignalNan" {
    inline for ([_]type{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        // TODO: Signalling NaN values get converted to quiet NaN values in
        //       some cases where they shouldn't such that this can fail.
        // try expect(isSignalNan(math.snan(T)));
        try expect(!isSignalNan(math.nan(T)));
        try expect(!isSignalNan(@as(T, 1.0)));
        try expect(!isSignalNan(math.inf(T)));
    }
}

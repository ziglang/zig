const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns whether x is negative or negative 0.
pub fn signbit(x: anytype) bool {
    const T = @TypeOf(x);
    const TBits = std.meta.Int(.unsigned, @typeInfo(T).float.bits);
    return @as(TBits, @bitCast(x)) >> (@bitSizeOf(T) - 1) != 0;
}

test signbit {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try expect(!signbit(@as(T, 0.0)));
        try expect(!signbit(@as(T, 1.0)));
        try expect(signbit(@as(T, -2.0)));
        try expect(signbit(@as(T, -0.0)));
        try expect(!signbit(math.inf(T)));
        try expect(signbit(-math.inf(T)));
        try expect(!signbit(math.nan(T)));
        try expect(signbit(-math.nan(T)));
    }
}

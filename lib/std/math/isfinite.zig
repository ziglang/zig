const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns whether x is a finite value.
pub fn isFinite(x: anytype) bool {
    const T = @TypeOf(x);
    const TBits = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
    const remove_sign = ~@as(TBits, 0) >> 1;
    return @as(TBits, @bitCast(x)) & remove_sign < @as(TBits, @bitCast(math.inf(T)));
}

test "math.isFinite" {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        // normals
        try expect(isFinite(@as(T, 1.0)));
        try expect(isFinite(-@as(T, 1.0)));

        // zero & subnormals
        try expect(isFinite(@as(T, 0.0)));
        try expect(isFinite(@as(T, -0.0)));
        try expect(isFinite(math.floatTrueMin(T)));

        // other float limits
        try expect(isFinite(math.floatMin(T)));
        try expect(isFinite(math.floatMax(T)));

        // inf & nan
        try expect(!isFinite(math.inf(T)));
        try expect(!isFinite(-math.inf(T)));
        try expect(!isFinite(math.nan(T)));
        try expect(!isFinite(-math.nan(T)));
    }
}

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the absolute value of x.
///
/// Special Cases:
///  - fabs(+-inf) = +inf
///  - fabs(nan)   = nan
pub fn fabs(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    const TBits = std.meta.Int(.unsigned, @bitSizeOf(T));
    if (@typeInfo(T) != .Float) {
        @compileError("fabs not implemented for " ++ @typeName(T));
    }

    const float_bits = @bitCast(TBits, x);
    const remove_sign = ~@as(TBits, 0) >> 1;

    return @bitCast(T, float_bits & remove_sign);
}

test "math.fabs" {
    // TODO add support for f80 & c_longdouble here
    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        // normals
        try expect(fabs(@as(T, 1.0)) == 1.0);
        try expect(fabs(@as(T, -1.0)) == 1.0);
        try expect(fabs(math.floatMin(T)) == math.floatMin(T));
        try expect(fabs(-math.floatMin(T)) == math.floatMin(T));
        try expect(fabs(math.floatMax(T)) == math.floatMax(T));
        try expect(fabs(-math.floatMax(T)) == math.floatMax(T));

        // subnormals
        try expect(fabs(@as(T, 0.0)) == 0.0);
        try expect(fabs(@as(T, -0.0)) == 0.0);
        try expect(fabs(math.floatTrueMin(T)) == math.floatTrueMin(T));
        try expect(fabs(-math.floatTrueMin(T)) == math.floatTrueMin(T));

        // non-finite numbers
        try expect(math.isPositiveInf(fabs(math.inf(T))));
        try expect(math.isPositiveInf(fabs(-math.inf(T))));
        try expect(math.isNan(fabs(math.nan(T))));
    }
}

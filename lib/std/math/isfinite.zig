const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns whether x is a finite value.
pub fn isFinite(x: anytype) bool {
    const T = @TypeOf(x);
    const TBits = std.meta.Int(.unsigned, @bitSizeOf(T));
    if (@typeInfo(T) != .Float) {
        @compileError("isFinite not implemented for " ++ @typeName(T));
    }
    const exponent_bits = math.floatExponentBits(T);
    const mantissa_bits = math.floatMantissaBits(T);
    const all1s_exponent = ((1 << exponent_bits) - 1) << mantissa_bits;
    const remove_sign = ~@as(TBits, 0) >> 1;
    return @bitCast(TBits, x) & remove_sign < all1s_exponent;
}

test "math.isFinite" {
    // TODO remove when #11391 is resolved
    if (@import("builtin").os.tag == .freebsd) return error.SkipZigTest;

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

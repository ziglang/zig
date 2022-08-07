const std = @import("../std.zig");
const math = std.math;
const meta = std.meta;
const expect = std.testing.expect;

/// Returns whether x is a nan.
pub fn isNan(x: anytype) bool {
    return x != x;
}

/// Returns whether x is a signalling nan.
pub fn isSignalNan(x: anytype) bool {
    const T = @TypeOf(x);
    const U = meta.Int(.unsigned, meta.bitCount(T));
    const signal_bit_mask = 1 << (math.floatMantissaBits(T) - 1);
    return isNan(x) and (@bitCast(U, x) & signal_bit_mask == 0);
}

/// Get a signalling NaN - currently only provided for testing.
fn snan(comptime T: type) T {
    const U = meta.Int(.unsigned, meta.bitCount(T));
    return @bitCast(T, @bitCast(U, math.inf(T)) + 1);
}

test "math.isNan" {
    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        try expect(isNan(math.nan(T)));
        try expect(isNan(snan(T)));
        try expect(!isNan(@as(T, 1.0)));
        try expect(!isNan(math.inf(T)));
    }
}

test "math.isSignalNan" {
    // TODO: Currently broken for f32, see #10449.
    inline for ([_]type{ f16, f64, f128 }) |T| {
        try expect(isSignalNan(snan(T)));
        try expect(!isSignalNan(math.nan(T)));
        try expect(!isSignalNan(@as(T, 1.0)));
        try expect(!isSignalNan(math.inf(T)));
    }
}

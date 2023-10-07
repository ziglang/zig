const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns a value with the magnitude of `magnitude` and the sign of `sign`.
pub fn copysign(magnitude: anytype, sign: @TypeOf(magnitude)) @TypeOf(magnitude) {
    const T = @TypeOf(magnitude);
    const TBits = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
    const sign_bit_mask = @as(TBits, 1) << (@bitSizeOf(T) - 1);
    const mag = @as(TBits, @bitCast(magnitude)) & ~sign_bit_mask;
    const sgn = @as(TBits, @bitCast(sign)) & sign_bit_mask;
    return @as(T, @bitCast(mag | sgn));
}

test "math.copysign" {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try expect(copysign(@as(T, 1.0), @as(T, 1.0)) == 1.0);
        try expect(copysign(@as(T, 2.0), @as(T, -2.0)) == -2.0);
        try expect(copysign(@as(T, -3.0), @as(T, 3.0)) == 3.0);
        try expect(copysign(@as(T, -4.0), @as(T, -4.0)) == -4.0);
        try expect(copysign(@as(T, 5.0), @as(T, -500.0)) == -5.0);
        try expect(copysign(math.inf(T), @as(T, -0.0)) == -math.inf(T));
        try expect(copysign(@as(T, 6.0), -math.nan(T)) == -6.0);
    }
}

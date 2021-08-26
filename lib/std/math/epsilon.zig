const math = @import("../math.zig");

/// Returns the machine epsilon for type T.
/// This is the smallest value of type T that satisfies the inequality 1.0 +
/// epsilon != 1.0.
pub fn epsilon(comptime T: type) T {
    return switch (T) {
        f16 => math.f16_epsilon,
        f32 => math.f32_epsilon,
        f64 => math.f64_epsilon,
        f128 => math.f128_epsilon,
        else => @compileError("epsilon not implemented for " ++ @typeName(T)),
    };
}

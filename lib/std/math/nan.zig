const math = @import("../math.zig");

/// Returns the canonical NaN representation for type T.
pub fn nan(comptime T: type) T {
    return switch (T) {
        f16 => math.qnan_f16,
        f32 => math.qnan_f32,
        f64 => math.qnan_f64,
        f128 => math.qnan_f128,
        else => @compileError("nan not implemented for " ++ @typeName(T)),
    };
}

/// Returns the canonical signalling NaN representation for type T.
pub fn snan(comptime T: type) T {
    return switch (T) {
        f16 => math.snan_f16,
        f32 => math.snan_f32,
        f64 => math.snan_f64,
        f128 => math.snan_f128,
        else => @compileError("snan not implemented for " ++ @typeName(T)),
    };
}

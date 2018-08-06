const math = @import("index.zig");

pub fn nan(comptime T: type) T {
    return switch (T) {
        f16 => @bitCast(f16, math.nan_u16),
        f32 => @bitCast(f32, math.nan_u32),
        f64 => @bitCast(f64, math.nan_u64),
        else => @compileError("nan not implemented for " ++ @typeName(T)),
    };
}

// Note: A signalling nan is identical to a standard right now by may have a different bit
// representation in the future when required.
pub fn snan(comptime T: type) T {
    return switch (T) {
        f16 => @bitCast(f16, math.nan_u16),
        f32 => @bitCast(f32, math.nan_u32),
        f64 => @bitCast(f64, math.nan_u64),
        else => @compileError("snan not implemented for " ++ @typeName(T)),
    };
}

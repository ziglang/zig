const math = @import("../math.zig");

/// Returns the nan representation for type T.
pub inline fn nan(comptime T: type) T {
    return switch (@typeInfo(T).Float.bits) {
        16 => math.nan_f16,
        32 => math.nan_f32,
        64 => math.nan_f64,
        80 => math.nan_f80,
        128 => math.nan_f128,
        else => @compileError("unreachable"),
    };
}

/// Returns the signalling nan representation for type T.
/// Note: A signalling nan is identical to a standard right now by may have a different bit
/// representation in the future when required.
pub inline fn snan(comptime T: type) T {
    return nan(T);
}

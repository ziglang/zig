const std = @import("../std.zig");
const math = std.math;

/// Returns value inf for the type T.
pub fn inf(comptime T: type) T {
    return switch (T) {
        f16 => math.inf_f16,
        f32 => math.inf_f32,
        f64 => math.inf_f64,
        f128 => math.inf_f128,
        else => @compileError("inf not implemented for " ++ @typeName(T)),
    };
}

const std = @import("../index.zig");
const math = std.math;

pub fn inf(comptime T: type) T {
    return switch (T) {
        f16 => @bitCast(f16, math.inf_u16),
        f32 => @bitCast(f32, math.inf_u32),
        f64 => @bitCast(f64, math.inf_u64),
        else => @compileError("inf not implemented for " ++ @typeName(T)),
    };
}

const math = @import("index.zig");

pub const nan = nan_workaround;

pub fn nan_workaround(comptime T: type) -> T {
    switch (T) {
        f32 => @bitCast(f32, math.nan_u32),
        f64 => @bitCast(f64, math.nan_u64),
        else => @compileError("nan not implemented for " ++ @typeName(T)),
    }
}

pub const snan = snan_workaround;

// Note: A signalling nan is identical to a standard right now by may have a different bit
// representation in the future when required.
pub fn snan_workaround(comptime T: type) -> T {
    switch (T) {
        f32 => @bitCast(f32, math.nan_u32),
        f64 => @bitCast(f64, math.nan_u64),
        else => @compileError("snan not implemented for " ++ @typeName(T)),
    }
}

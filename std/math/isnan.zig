const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn isNan(x: var) bool {
    const T = @typeOf(x);
    switch (T) {
        f16 => {
            const bits = @bitCast(u16, x);
            return (bits & 0x7fff) > 0x7c00;
        },
        f32 => {
            const bits = @bitCast(u32, x);
            return bits & 0x7FFFFFFF > 0x7F800000;
        },
        f64 => {
            const bits = @bitCast(u64, x);
            return (bits & (@maxValue(u64) >> 1)) > (u64(0x7FF) << 52);
        },
        else => {
            @compileError("isNan not implemented for " ++ @typeName(T));
        },
    }
}

// Note: A signalling nan is identical to a standard right now by may have a different bit
// representation in the future when required.
pub fn isSignalNan(x: var) bool {
    return isNan(x);
}

test "math.isNan" {
    assert(isNan(math.nan(f16)));
    assert(isNan(math.nan(f32)));
    assert(isNan(math.nan(f64)));
    assert(!isNan(f16(1.0)));
    assert(!isNan(f32(1.0)));
    assert(!isNan(f64(1.0)));
}

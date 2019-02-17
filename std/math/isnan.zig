const std = @import("../index.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

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
            return (bits & (maxInt(u64) >> 1)) > (u64(0x7FF) << 52);
        },
        f128 => {
            const bits = @bitCast(u128, x);
            return (bits & (maxInt(u128) >> 1)) > (u128(0x7FFF) << 112);
        },
        else => {
            @compileError("isNan not implemented for " ++ @typeName(T));
        },
    }
}

/// Note: A signalling nan is identical to a standard nan right now but may have a different bit
/// representation in the future when required.
pub fn isSignalNan(x: var) bool {
    return isNan(x);
}

test "math.isNan" {
    expect(isNan(math.nan(f16)));
    expect(isNan(math.nan(f32)));
    expect(isNan(math.nan(f64)));
    expect(isNan(math.nan(f128)));
    expect(!isNan(f16(1.0)));
    expect(!isNan(f32(1.0)));
    expect(!isNan(f64(1.0)));
    expect(!isNan(f128(1.0)));
}

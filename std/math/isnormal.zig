const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn isNormal(x: var) -> bool {
    const T = @typeOf(x);
    switch (T) {
        f32 => {
            const bits = @bitCast(u32, x);
            return (bits + 0x00800000) & 0x7FFFFFFF >= 0x01000000;
        },
        f64 => {
            const bits = @bitCast(u64, x);
            return (bits + (1 << 52)) & (@maxValue(u64) >> 1) >= (1 << 53);
        },
        else => {
            @compileError("isNormal not implemented for " ++ @typeName(T));
        },
    }
}

test "math.isNormal" {
    assert(!isNormal(math.nan(f32)));
    assert(!isNormal(math.nan(f64)));
    assert(isNormal(f32(1.0)));
    assert(isNormal(f64(1.0)));
}

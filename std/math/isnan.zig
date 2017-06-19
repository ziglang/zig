const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn isNan(x: var) -> bool {
    const T = @typeOf(x);
    switch (T) {
        f32 => {
            const bits = @bitCast(u32, x);
            bits & 0x7FFFFFFF > 0x7F800000
        },
        f64 => {
            const bits = @bitCast(u64, x);
            (bits & (@maxValue(u64) >> 1)) > (u64(0x7FF) << 52)
        },
        else => {
            @compileError("isNan not implemented for " ++ @typeName(T));
        },
    }
}

test "math.isNan" {
    assert(isNan(math.nan(f32)));
    assert(isNan(math.nan(f64)));
    assert(!isNan(f32(1.0)));
    assert(!isNan(f64(1.0)));
}

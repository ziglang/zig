const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn isFinite(x: var) -> bool {
    const T = @typeOf(x);
    switch (T) {
        f32 => {
            const bits = @bitCast(u32, x);
            return bits & 0x7FFFFFFF < 0x7F800000;
        },
        f64 => {
            const bits = @bitCast(u64, x);
            return bits & (@maxValue(u64) >> 1) < (0x7FF << 52);
        },
        else => {
            @compileError("isFinite not implemented for " ++ @typeName(T));
        },
    }
}

test "math.isFinite" {
    assert(isFinite(f32(0.0)));
    assert(isFinite(f32(-0.0)));
    assert(isFinite(f64(0.0)));
    assert(isFinite(f64(-0.0)));
    assert(!isFinite(math.inf(f32)));
    assert(!isFinite(-math.inf(f32)));
    assert(!isFinite(math.inf(f64)));
    assert(!isFinite(-math.inf(f64)));
}

const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn isFinite(x: var) bool {
    const T = @typeOf(x);
    switch (T) {
        f16 => {
            const bits = @bitCast(u16, x);
            return bits & 0x7FFF < 0x7C00;
        },
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
    assert(isFinite(f16(0.0)));
    assert(isFinite(f16(-0.0)));
    assert(isFinite(f32(0.0)));
    assert(isFinite(f32(-0.0)));
    assert(isFinite(f64(0.0)));
    assert(isFinite(f64(-0.0)));
    assert(!isFinite(math.inf(f16)));
    assert(!isFinite(-math.inf(f16)));
    assert(!isFinite(math.inf(f32)));
    assert(!isFinite(-math.inf(f32)));
    assert(!isFinite(math.inf(f64)));
    assert(!isFinite(-math.inf(f64)));
}

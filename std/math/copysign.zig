const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn copysign(comptime T: type, x: T, y: T) -> T {
    switch (T) {
        f32 => @inlineCall(copysign32, x, y),
        f64 => @inlineCall(copysign64, x, y),
        else => @compileError("copysign not implemented for " ++ @typeName(T)),
    }
}

fn copysign32(x: f32, y: f32) -> f32 {
    const ux = @bitCast(u32, x);
    const uy = @bitCast(u32, y);

    const h1 = ux & (@maxValue(u32) / 2);
    const h2 = uy & (u32(1) << 31);
    @bitCast(f32, h1 | h2)
}

fn copysign64(x: f64, y: f64) -> f64 {
    const ux = @bitCast(u64, x);
    const uy = @bitCast(u64, y);

    const h1 = ux & (@maxValue(u64) / 2);
    const h2 = uy & (u64(1) << 63);
    @bitCast(f64, h1 | h2)
}

test "copysign" {
    assert(copysign(f32, 1.0, 1.0) == copysign32(1.0, 1.0));
    assert(copysign(f64, 1.0, 1.0) == copysign64(1.0, 1.0));
}

test "copysign32" {
    assert(copysign32(5.0, 1.0) == 5.0);
    assert(copysign32(5.0, -1.0) == -5.0);
    assert(copysign32(-5.0, -1.0) == -5.0);
    assert(copysign32(-5.0, 1.0) == 5.0);
}

test "copysign64" {
    assert(copysign64(5.0, 1.0) == 5.0);
    assert(copysign64(5.0, -1.0) == -5.0);
    assert(copysign64(-5.0, -1.0) == -5.0);
    assert(copysign64(-5.0, 1.0) == 5.0);
}

const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn copysign(comptime T: type, x: T, y: T) T {
    return switch (T) {
        f16 => copysign16(x, y),
        f32 => copysign32(x, y),
        f64 => copysign64(x, y),
        else => @compileError("copysign not implemented for " ++ @typeName(T)),
    };
}

fn copysign16(x: f16, y: f16) f16 {
    const ux = @bitCast(u16, x);
    const uy = @bitCast(u16, y);

    const h1 = ux & (@maxValue(u16) / 2);
    const h2 = uy & (u16(1) << 15);
    return @bitCast(f16, h1 | h2);
}

fn copysign32(x: f32, y: f32) f32 {
    const ux = @bitCast(u32, x);
    const uy = @bitCast(u32, y);

    const h1 = ux & (@maxValue(u32) / 2);
    const h2 = uy & (u32(1) << 31);
    return @bitCast(f32, h1 | h2);
}

fn copysign64(x: f64, y: f64) f64 {
    const ux = @bitCast(u64, x);
    const uy = @bitCast(u64, y);

    const h1 = ux & (@maxValue(u64) / 2);
    const h2 = uy & (u64(1) << 63);
    return @bitCast(f64, h1 | h2);
}

test "math.copysign" {
    assert(copysign(f16, 1.0, 1.0) == copysign16(1.0, 1.0));
    assert(copysign(f32, 1.0, 1.0) == copysign32(1.0, 1.0));
    assert(copysign(f64, 1.0, 1.0) == copysign64(1.0, 1.0));
}

test "math.copysign16" {
    assert(copysign16(5.0, 1.0) == 5.0);
    assert(copysign16(5.0, -1.0) == -5.0);
    assert(copysign16(-5.0, -1.0) == -5.0);
    assert(copysign16(-5.0, 1.0) == 5.0);
}

test "math.copysign32" {
    assert(copysign32(5.0, 1.0) == 5.0);
    assert(copysign32(5.0, -1.0) == -5.0);
    assert(copysign32(-5.0, -1.0) == -5.0);
    assert(copysign32(-5.0, 1.0) == 5.0);
}

test "math.copysign64" {
    assert(copysign64(5.0, 1.0) == 5.0);
    assert(copysign64(5.0, -1.0) == -5.0);
    assert(copysign64(-5.0, -1.0) == -5.0);
    assert(copysign64(-5.0, 1.0) == 5.0);
}

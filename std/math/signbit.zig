const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn signbit(x: var) bool {
    const T = @typeOf(x);
    return switch (T) {
        f16 => signbit16(x),
        f32 => signbit32(x),
        f64 => signbit64(x),
        else => @compileError("signbit not implemented for " ++ @typeName(T)),
    };
}

fn signbit16(x: f16) bool {
    const bits = @bitCast(u16, x);
    return bits >> 15 != 0;
}

fn signbit32(x: f32) bool {
    const bits = @bitCast(u32, x);
    return bits >> 31 != 0;
}

fn signbit64(x: f64) bool {
    const bits = @bitCast(u64, x);
    return bits >> 63 != 0;
}

test "math.signbit" {
    assert(signbit(f16(4.0)) == signbit16(4.0));
    assert(signbit(f32(4.0)) == signbit32(4.0));
    assert(signbit(f64(4.0)) == signbit64(4.0));
}

test "math.signbit16" {
    assert(!signbit16(4.0));
    assert(signbit16(-3.0));
}

test "math.signbit32" {
    assert(!signbit32(4.0));
    assert(signbit32(-3.0));
}

test "math.signbit64" {
    assert(!signbit64(4.0));
    assert(signbit64(-3.0));
}

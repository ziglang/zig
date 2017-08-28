const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn signbit(x: var) -> bool {
    const T = @typeOf(x);
    switch (T) {
        f32 => @inlineCall(signbit32, x),
        f64 => @inlineCall(signbit64, x),
        else => @compileError("signbit not implemented for " ++ @typeName(T)),
    }
}

fn signbit32(x: f32) -> bool {
    const bits = @bitCast(u32, x);
    bits >> 31 != 0
}

fn signbit64(x: f64) -> bool {
    const bits = @bitCast(u64, x);
    bits >> 63 != 0
}

test "math.signbit" {
    assert(signbit(f32(4.0)) == signbit32(4.0));
    assert(signbit(f64(4.0)) == signbit64(4.0));
}

test "math.signbit32" {
    assert(!signbit32(4.0));
    assert(signbit32(-3.0));
}

test "math.signbit64" {
    assert(!signbit64(4.0));
    assert(signbit64(-3.0));
}

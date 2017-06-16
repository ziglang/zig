const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn fabs(x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    switch (T) {
        f32 => @inlineCall(fabs32, x),
        f64 => @inlineCall(fabs64, x),
        else => @compileError("fabs not implemented for " ++ @typeName(T)),
    }
}

fn fabs32(x: f32) -> f32 {
    var u = @bitCast(u32, x);
    u &= 0x7FFFFFFF;
    @bitCast(f32, u)
}

fn fabs64(x: f64) -> f64 {
    var u = @bitCast(u64, x);
    u &= @maxValue(u64) >> 1;
    @bitCast(f64, u)
}

test "fabs" {
    assert(fabs(f32(1.0)) == fabs32(1.0));
    assert(fabs(f64(1.0)) == fabs64(1.0));
}

test "fabs32" {
    assert(fabs64(1.0) == 1.0);
    assert(fabs64(-1.0) == 1.0);
}

test "fabs64" {
    assert(fabs64(1.0) == 1.0);
    assert(fabs64(-1.0) == 1.0);
}

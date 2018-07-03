// Special Cases:
//
// - fabs(+-inf) = +inf
// - fabs(nan)   = nan

const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn fabs(x: var) @typeOf(x) {
    const T = @typeOf(x);
    return switch (T) {
        f16 => fabs16(x),
        f32 => fabs32(x),
        f64 => fabs64(x),
        else => @compileError("fabs not implemented for " ++ @typeName(T)),
    };
}

fn fabs16(x: f16) f16 {
    var u = @bitCast(u16, x);
    u &= 0x7FFF;
    return @bitCast(f16, u);
}

fn fabs32(x: f32) f32 {
    var u = @bitCast(u32, x);
    u &= 0x7FFFFFFF;
    return @bitCast(f32, u);
}

fn fabs64(x: f64) f64 {
    var u = @bitCast(u64, x);
    u &= @maxValue(u64) >> 1;
    return @bitCast(f64, u);
}

test "math.fabs" {
    assert(fabs(f16(1.0)) == fabs16(1.0));
    assert(fabs(f32(1.0)) == fabs32(1.0));
    assert(fabs(f64(1.0)) == fabs64(1.0));
}

test "math.fabs16" {
    assert(fabs16(1.0) == 1.0);
    assert(fabs16(-1.0) == 1.0);
}

test "math.fabs32" {
    assert(fabs32(1.0) == 1.0);
    assert(fabs32(-1.0) == 1.0);
}

test "math.fabs64" {
    assert(fabs64(1.0) == 1.0);
    assert(fabs64(-1.0) == 1.0);
}

test "math.fabs16.special" {
    assert(math.isPositiveInf(fabs(math.inf(f16))));
    assert(math.isPositiveInf(fabs(-math.inf(f16))));
    assert(math.isNan(fabs(math.nan(f16))));
}

test "math.fabs32.special" {
    assert(math.isPositiveInf(fabs(math.inf(f32))));
    assert(math.isPositiveInf(fabs(-math.inf(f32))));
    assert(math.isNan(fabs(math.nan(f32))));
}

test "math.fabs64.special" {
    assert(math.isPositiveInf(fabs(math.inf(f64))));
    assert(math.isPositiveInf(fabs(-math.inf(f64))));
    assert(math.isNan(fabs(math.nan(f64))));
}

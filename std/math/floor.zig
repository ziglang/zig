// Special Cases:
//
// - floor(+-0)   = +-0
// - floor(+-inf) = +-inf
// - floor(nan)   = nan

const builtin = @import("builtin");
const assert = std.debug.assert;
const std = @import("../index.zig");
const math = std.math;

pub fn floor(x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    return switch (T) {
        f32 => floor32(x),
        f64 => floor64(x),
        else => @compileError("floor not implemented for " ++ @typeName(T)),
    };
}

fn floor32(x: f32) -> f32 {
    var u = @bitCast(u32, x);
    const e = i32((u >> 23) & 0xFF) - 0x7F;
    var m: u32 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 23) {
        return x;
    }

    if (e >= 0) {
        m = u32(0x007FFFFF) >> u5(e);
        if (u & m == 0) {
            return x;
        }
        math.forceEval(x + 0x1.0p120);
        if (u >> 31 != 0) {
            u += m;
        }
        return @bitCast(f32, u & ~m);
    } else {
        math.forceEval(x + 0x1.0p120);
        if (u >> 31 == 0) {
            return 0.0;
        } else {
            return -1.0;
        }
    }
}

fn floor64(x: f64) -> f64 {
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF+52 or x == 0) {
        return x;
    }

    if (u >> 63 != 0) {
        @setFloatMode(this, builtin.FloatMode.Strict);
        y = x - math.f64_toint + math.f64_toint - x;
    } else {
        @setFloatMode(this, builtin.FloatMode.Strict);
        y = x + math.f64_toint - math.f64_toint - x;
    }

    if (e <= 0x3FF-1) {
        math.forceEval(y);
        if (u >> 63 != 0) {
            return -1.0;
        } else {
            return 0.0;
        }
    } else if (y > 0) {
        return x + y - 1;
    } else {
        return x + y;
    }
}

test "math.floor" {
    assert(floor(f32(1.3)) == floor32(1.3));
    assert(floor(f64(1.3)) == floor64(1.3));
}

test "math.floor32" {
    assert(floor32(1.3) == 1.0);
    assert(floor32(-1.3) == -2.0);
    assert(floor32(0.2) == 0.0);
}

test "math.floor64" {
    assert(floor64(1.3) == 1.0);
    assert(floor64(-1.3) == -2.0);
    assert(floor64(0.2) == 0.0);
}

test "math.floor32.special" {
    assert(floor32(0.0) == 0.0);
    assert(floor32(-0.0) == -0.0);
    assert(math.isPositiveInf(floor32(math.inf(f32))));
    assert(math.isNegativeInf(floor32(-math.inf(f32))));
    assert(math.isNan(floor32(math.nan(f32))));
}

test "math.floor64.special" {
    assert(floor64(0.0) == 0.0);
    assert(floor64(-0.0) == -0.0);
    assert(math.isPositiveInf(floor64(math.inf(f64))));
    assert(math.isNegativeInf(floor64(-math.inf(f64))));
    assert(math.isNan(floor64(math.nan(f64))));
}

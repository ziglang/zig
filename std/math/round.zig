const builtin = @import("builtin");
const assert = @import("../debug.zig").assert;
const math = @import("index.zig");

// TODO issue #393
pub const round = round_workaround;

pub fn round_workaround(x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    switch (T) {
        f32 => @inlineCall(round32, x),
        f64 => @inlineCall(round64, x),
        else => @compileError("round not implemented for " ++ @typeName(T)),
    }
}

fn round32(x_: f32) -> f32 {
    var x = x_;
    const u = @bitCast(u32, x);
    const e = (u >> 23) & 0xFF;
    var y: f32 = undefined;

    if (e >= 0x7F+23) {
        return x;
    }
    if (u >> 31 != 0) {
        x = -x;
    }
    if (e < 0x7F-1) {
        math.forceEval(x + math.f32_toint);
        return 0 * @bitCast(f32, u);
    }

    {
        @setFloatMode(this, builtin.FloatMode.Strict);
        y = x + math.f32_toint - math.f32_toint - x;
    }

    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 31 != 0) {
        -y
    } else {
        y
    }
}

fn round64(x_: f64) -> f64 {
    var x = x_;
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF+52) {
        return x;
    }
    if (u >> 63 != 0) {
        x = -x;
    }
    if (e < 0x3ff-1) {
        math.forceEval(x + math.f64_toint);
        return 0 * @bitCast(f64, u);
    }

    {
        @setFloatMode(this, builtin.FloatMode.Strict);
        y = x + math.f64_toint - math.f64_toint - x;
    }

    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 63 != 0) {
        -y
    } else {
        y
    }
}

test "math.round" {
    assert(round(f32(1.3)) == round32(1.3));
    assert(round(f64(1.3)) == round64(1.3));
}

test "math.round32" {
    assert(round32(1.3) == 1.0);
    assert(round32(-1.3) == -1.0);
    assert(round32(0.2) == 0.0);
    assert(round32(1.8) == 2.0);
}

test "math.round64" {
    assert(round64(1.3) == 1.0);
    assert(round64(-1.3) == -1.0);
    assert(round64(0.2) == 0.0);
    assert(round64(1.8) == 2.0);
}

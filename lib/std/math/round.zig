// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/roundf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/round.c

const builtin = @import("builtin");
const expect = std.testing.expect;
const std = @import("../std.zig");
const math = std.math;

/// Returns x rounded to the nearest integer, rounding half away from zero.
///
/// Special Cases:
///  - round(+-0)   = +-0
///  - round(+-inf) = +-inf
///  - round(nan)   = nan
pub fn round(x: var) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => round32(x),
        f64 => round64(x),
        else => @compileError("round not implemented for " ++ @typeName(T)),
    };
}

fn round32(x_: f32) f32 {
    var x = x_;
    const u = @bitCast(u32, x);
    const e = (u >> 23) & 0xFF;
    var y: f32 = undefined;

    if (e >= 0x7F + 23) {
        return x;
    }
    if (u >> 31 != 0) {
        x = -x;
    }
    if (e < 0x7F - 1) {
        math.forceEval(x + math.f32_toint);
        return 0 * @bitCast(f32, u);
    }

    y = x + math.f32_toint - math.f32_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 31 != 0) {
        return -y;
    } else {
        return y;
    }
}

fn round64(x_: f64) f64 {
    var x = x_;
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF + 52) {
        return x;
    }
    if (u >> 63 != 0) {
        x = -x;
    }
    if (e < 0x3ff - 1) {
        math.forceEval(x + math.f64_toint);
        return 0 * @bitCast(f64, u);
    }

    y = x + math.f64_toint - math.f64_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 63 != 0) {
        return -y;
    } else {
        return y;
    }
}

test "math.round" {
    expect(round(@as(f32, 1.3)) == round32(1.3));
    expect(round(@as(f64, 1.3)) == round64(1.3));
}

test "math.round32" {
    expect(round32(1.3) == 1.0);
    expect(round32(-1.3) == -1.0);
    expect(round32(0.2) == 0.0);
    expect(round32(1.8) == 2.0);
}

test "math.round64" {
    expect(round64(1.3) == 1.0);
    expect(round64(-1.3) == -1.0);
    expect(round64(0.2) == 0.0);
    expect(round64(1.8) == 2.0);
}

test "math.round32.special" {
    expect(round32(0.0) == 0.0);
    expect(round32(-0.0) == -0.0);
    expect(math.isPositiveInf(round32(math.inf(f32))));
    expect(math.isNegativeInf(round32(-math.inf(f32))));
    expect(math.isNan(round32(math.nan(f32))));
}

test "math.round64.special" {
    expect(round64(0.0) == 0.0);
    expect(round64(-0.0) == -0.0);
    expect(math.isPositiveInf(round64(math.inf(f64))));
    expect(math.isNegativeInf(round64(-math.inf(f64))));
    expect(math.isNan(round64(math.nan(f64))));
}

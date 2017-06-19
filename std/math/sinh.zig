const math = @import("index.zig");
const assert = @import("../debug.zig").assert;
const expo2 = @import("_expo2.zig").expo2;

// TODO issue #393
pub const sinh = sinh_workaround;

pub fn sinh_workaround(x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    switch (T) {
        f32 => @inlineCall(sinh32, x),
        f64 => @inlineCall(sinh64, x),
        else => @compileError("sinh not implemented for " ++ @typeName(T)),
    }
}

// sinh(x) = (exp(x) - 1 / exp(x)) / 2
//         = (exp(x) - 1 + (exp(x) - 1) / exp(x)) / 2
//         = x + x^3 / 6 + o(x^5)
fn sinh32(x: f32) -> f32 {
    const u = @bitCast(u32, x);
    const ux = u & 0x7FFFFFFF;
    const ax = @bitCast(f32, ux);

    var h: f32 = 0.5;
    if (u >> 31 != 0) {
        h = -h;
    }

    // |x| < log(FLT_MAX)
    if (ux < 0x42B17217) {
        const t = math.expm1(ax);
        if (ux < 0x3F800000) {
            if (ux < 0x3F800000 - (12 << 23)) {
                return x;
            } else {
                return h * (2 * t - t * t / (t + 1));
            }
        }
        return h * (t + t / (t + 1));
    }

    // |x| > log(FLT_MAX) or nan
    2 * h * expo2(ax)
}

fn sinh64(x: f64) -> f64 {
    const u = @bitCast(u64, x);
    const w = u32(u >> 32);
    const ax = @bitCast(f64, u & (@maxValue(u64) >> 1));

    var h: f32 = 0.5;
    if (u >> 63 != 0) {
        h = -h;
    }

    // |x| < log(FLT_MAX)
    if (w < 0x40862E42) {
        const t = math.expm1(ax);
        if (w < 0x3FF00000) {
            if (w < 0x3FF00000 - (26 << 20)) {
                return x;
            } else {
                return h * (2 * t - t * t / (t + 1));
            }
        }
        // NOTE: |x| > log(0x1p26) + eps could be h * exp(x)
        return h * (t + t / (t + 1));
    }

    // |x| > log(DBL_MAX) or nan
    2 * h * expo2(ax)
}

test "math.sinh" {
    assert(sinh(f32(1.5)) == sinh32(1.5));
    assert(sinh(f64(1.5)) == sinh64(1.5));
}

test "math.sinh32" {
    const epsilon = 0.000001;

    assert(math.approxEq(f32, sinh32(0.0), 0.0, epsilon));
    assert(math.approxEq(f32, sinh32(0.2), 0.201336, epsilon));
    assert(math.approxEq(f32, sinh32(0.8923), 1.015512, epsilon));
    assert(math.approxEq(f32, sinh32(1.5), 2.129279, epsilon));
}

test "math.sinh64" {
    const epsilon = 0.000001;

    assert(math.approxEq(f64, sinh64(0.0), 0.0, epsilon));
    assert(math.approxEq(f64, sinh64(0.2), 0.201336, epsilon));
    assert(math.approxEq(f64, sinh64(0.8923), 1.015512, epsilon));
    assert(math.approxEq(f64, sinh64(1.5), 2.129279, epsilon));
}

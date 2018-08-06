// Special Cases:
//
// - cbrt(+-0)   = +-0
// - cbrt(+-inf) = +-inf
// - cbrt(nan)   = nan

const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn cbrt(x: var) @typeOf(x) {
    const T = @typeOf(x);
    return switch (T) {
        f32 => cbrt32(x),
        f64 => cbrt64(x),
        else => @compileError("cbrt not implemented for " ++ @typeName(T)),
    };
}

fn cbrt32(x: f32) f32 {
    const B1: u32 = 709958130; // (127 - 127.0 / 3 - 0.03306235651) * 2^23
    const B2: u32 = 642849266; // (127 - 127.0 / 3 - 24 / 3 - 0.03306235651) * 2^23

    var u = @bitCast(u32, x);
    var hx = u & 0x7FFFFFFF;

    // cbrt(nan, inf) = itself
    if (hx >= 0x7F800000) {
        return x + x;
    }

    // cbrt to ~5bits
    if (hx < 0x00800000) {
        // cbrt(+-0) = itself
        if (hx == 0) {
            return x;
        }
        u = @bitCast(u32, x * 0x1.0p24);
        hx = u & 0x7FFFFFFF;
        hx = hx / 3 + B2;
    } else {
        hx = hx / 3 + B1;
    }

    u &= 0x80000000;
    u |= hx;

    // first step newton to 16 bits
    var t: f64 = @bitCast(f32, u);
    var r: f64 = t * t * t;
    t = t * (f64(x) + x + r) / (x + r + r);

    // second step newton to 47 bits
    r = t * t * t;
    t = t * (f64(x) + x + r) / (x + r + r);

    return @floatCast(f32, t);
}

fn cbrt64(x: f64) f64 {
    const B1: u32 = 715094163; // (1023 - 1023 / 3 - 0.03306235651 * 2^20
    const B2: u32 = 696219795; // (1023 - 1023 / 3 - 54 / 3 - 0.03306235651 * 2^20

    // |1 / cbrt(x) - p(x)| < 2^(23.5)
    const P0: f64 = 1.87595182427177009643;
    const P1: f64 = -1.88497979543377169875;
    const P2: f64 = 1.621429720105354466140;
    const P3: f64 = -0.758397934778766047437;
    const P4: f64 = 0.145996192886612446982;

    var u = @bitCast(u64, x);
    var hx = @intCast(u32, u >> 32) & 0x7FFFFFFF;

    // cbrt(nan, inf) = itself
    if (hx >= 0x7FF00000) {
        return x + x;
    }

    // cbrt to ~5bits
    if (hx < 0x00100000) {
        u = @bitCast(u64, x * 0x1.0p54);
        hx = @intCast(u32, u >> 32) & 0x7FFFFFFF;

        // cbrt(0) is itself
        if (hx == 0) {
            return 0;
        }
        hx = hx / 3 + B2;
    } else {
        hx = hx / 3 + B1;
    }

    u &= 1 << 63;
    u |= u64(hx) << 32;
    var t = @bitCast(f64, u);

    // cbrt to 23 bits
    // cbrt(x) = t * cbrt(x / t^3) ~= t * P(t^3 / x)
    var r = (t * t) * (t / x);
    t = t * ((P0 + r * (P1 + r * P2)) + ((r * r) * r) * (P3 + r * P4));

    // Round t away from 0 to 23 bits
    u = @bitCast(u64, t);
    u = (u + 0x80000000) & 0xFFFFFFFFC0000000;
    t = @bitCast(f64, u);

    // one step newton to 53 bits
    const s = t * t;
    var q = x / s;
    var w = t + t;
    q = (q - t) / (w + q);

    return t + t * q;
}

test "math.cbrt" {
    assert(cbrt(f32(0.0)) == cbrt32(0.0));
    assert(cbrt(f64(0.0)) == cbrt64(0.0));
}

test "math.cbrt32" {
    const epsilon = 0.000001;

    assert(cbrt32(0.0) == 0.0);
    assert(math.approxEq(f32, cbrt32(0.2), 0.584804, epsilon));
    assert(math.approxEq(f32, cbrt32(0.8923), 0.962728, epsilon));
    assert(math.approxEq(f32, cbrt32(1.5), 1.144714, epsilon));
    assert(math.approxEq(f32, cbrt32(37.45), 3.345676, epsilon));
    assert(math.approxEq(f32, cbrt32(123123.234375), 49.748501, epsilon));
}

test "math.cbrt64" {
    const epsilon = 0.000001;

    assert(cbrt64(0.0) == 0.0);
    assert(math.approxEq(f64, cbrt64(0.2), 0.584804, epsilon));
    assert(math.approxEq(f64, cbrt64(0.8923), 0.962728, epsilon));
    assert(math.approxEq(f64, cbrt64(1.5), 1.144714, epsilon));
    assert(math.approxEq(f64, cbrt64(37.45), 3.345676, epsilon));
    assert(math.approxEq(f64, cbrt64(123123.234375), 49.748501, epsilon));
}

test "math.cbrt.special" {
    assert(cbrt32(0.0) == 0.0);
    assert(cbrt32(-0.0) == -0.0);
    assert(math.isPositiveInf(cbrt32(math.inf(f32))));
    assert(math.isNegativeInf(cbrt32(-math.inf(f32))));
    assert(math.isNan(cbrt32(math.nan(f32))));
}

test "math.cbrt64.special" {
    assert(cbrt64(0.0) == 0.0);
    assert(cbrt64(-0.0) == -0.0);
    assert(math.isPositiveInf(cbrt64(math.inf(f64))));
    assert(math.isNegativeInf(cbrt64(-math.inf(f64))));
    assert(math.isNan(cbrt64(math.nan(f64))));
}

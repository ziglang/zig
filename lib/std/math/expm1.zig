// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/expmf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/expm.c

// TODO: Updated recently.

const builtin = @import("builtin");
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns e raised to the power of x, minus 1 (e^x - 1). This is more accurate than exp(e, x) - 1
/// when x is near 0.
///
/// Special Cases:
///  - expm1(+inf) = +inf
///  - expm1(-inf) = -1
///  - expm1(nan)  = nan
pub fn expm1(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => expm1_32(x),
        f64 => expm1_64(x),
        else => @compileError("exp1m not implemented for " ++ @typeName(T)),
    };
}

fn expm1_32(x_: f32) f32 {
    if (math.isNan(x_))
        return math.nan(f32);

    const o_threshold: f32 = 8.8721679688e+01;
    const ln2_hi: f32 = 6.9313812256e-01;
    const ln2_lo: f32 = 9.0580006145e-06;
    const invln2: f32 = 1.4426950216e+00;
    const Q1: f32 = -3.3333212137e-2;
    const Q2: f32 = 1.5807170421e-3;

    var x = x_;
    const ux = @bitCast(u32, x);
    const hx = ux & 0x7FFFFFFF;
    const sign = hx >> 31;

    // TODO: Shouldn't need this check explicitly.
    if (math.isNegativeInf(x)) {
        return -1.0;
    }

    // |x| >= 27 * ln2
    if (hx >= 0x4195B844) {
        // nan
        if (hx > 0x7F800000) {
            return x;
        }
        if (sign != 0) {
            return -1;
        }
        if (x > o_threshold) {
            x *= 0x1.0p127;
            return x;
        }
    }

    var hi: f32 = undefined;
    var lo: f32 = undefined;
    var c: f32 = undefined;
    var k: i32 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3EB17218) {
        // |x| < 1.5 * ln2
        if (hx < 0x3F851592) {
            if (sign == 0) {
                hi = x - ln2_hi;
                lo = ln2_lo;
                k = 1;
            } else {
                hi = x + ln2_hi;
                lo = -ln2_lo;
                k = -1;
            }
        } else {
            var kf = invln2 * x;
            if (sign != 0) {
                kf -= 0.5;
            } else {
                kf += 0.5;
            }

            k = @floatToInt(i32, kf);
            const t = @intToFloat(f32, k);
            hi = x - t * ln2_hi;
            lo = t * ln2_lo;
        }

        x = hi - lo;
        c = (hi - x) - lo;
    }
    // |x| < 2^(-25)
    else if (hx < 0x33000000) {
        if (hx < 0x00800000) {
            math.doNotOptimizeAway(x * x);
        }
        return x;
    } else {
        k = 0;
    }

    const hfx = 0.5 * x;
    const hxs = x * hfx;
    const r1 = 1.0 + hxs * (Q1 + hxs * Q2);
    const t = 3.0 - r1 * hfx;
    var e = hxs * ((r1 - t) / (6.0 - x * t));

    // c is 0
    if (k == 0) {
        return x - (x * e - hxs);
    }

    e = x * (e - c) - c;
    e -= hxs;

    // exp(x) ~ 2^k (x_reduced - e + 1)
    if (k == -1) {
        return 0.5 * (x - e) - 0.5;
    }
    if (k == 1) {
        if (x < -0.25) {
            return -2.0 * (e - (x + 0.5));
        } else {
            return 1.0 + 2.0 * (x - e);
        }
    }

    const twopk = @bitCast(f32, @intCast(u32, (0x7F +% k) << 23));

    if (k < 0 or k > 56) {
        var y = x - e + 1.0;
        if (k == 128) {
            y = y * 2.0 * 0x1.0p127;
        } else {
            y = y * twopk;
        }

        return y - 1.0;
    }

    const uf = @bitCast(f32, @intCast(u32, 0x7F -% k) << 23);
    if (k < 23) {
        return (x - e + (1 - uf)) * twopk;
    } else {
        return (x - (e + uf) + 1) * twopk;
    }
}

fn expm1_64(x_: f64) f64 {
    if (math.isNan(x_))
        return math.nan(f64);

    const o_threshold: f64 = 7.09782712893383973096e+02;
    const ln2_hi: f64 = 6.93147180369123816490e-01;
    const ln2_lo: f64 = 1.90821492927058770002e-10;
    const invln2: f64 = 1.44269504088896338700e+00;
    const Q1: f64 = -3.33333333333331316428e-02;
    const Q2: f64 = 1.58730158725481460165e-03;
    const Q3: f64 = -7.93650757867487942473e-05;
    const Q4: f64 = 4.00821782732936239552e-06;
    const Q5: f64 = -2.01099218183624371326e-07;

    var x = x_;
    const ux = @bitCast(u64, x);
    const hx = @intCast(u32, ux >> 32) & 0x7FFFFFFF;
    const sign = ux >> 63;

    if (math.isNegativeInf(x)) {
        return -1.0;
    }

    // |x| >= 56 * ln2
    if (hx >= 0x4043687A) {
        // exp1md(nan) = nan
        if (hx > 0x7FF00000) {
            return x;
        }
        // exp1md(-ve) = -1
        if (sign != 0) {
            return -1;
        }
        if (x > o_threshold) {
            math.raiseOverflow();
            return math.inf(f64);
        }
    }

    var hi: f64 = undefined;
    var lo: f64 = undefined;
    var c: f64 = undefined;
    var k: i32 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3FD62E42) {
        // |x| < 1.5 * ln2
        if (hx < 0x3FF0A2B2) {
            if (sign == 0) {
                hi = x - ln2_hi;
                lo = ln2_lo;
                k = 1;
            } else {
                hi = x + ln2_hi;
                lo = -ln2_lo;
                k = -1;
            }
        } else {
            var kf = invln2 * x;
            if (sign != 0) {
                kf -= 0.5;
            } else {
                kf += 0.5;
            }

            k = @floatToInt(i32, kf);
            const t = @intToFloat(f64, k);
            hi = x - t * ln2_hi;
            lo = t * ln2_lo;
        }

        x = hi - lo;
        c = (hi - x) - lo;
    }
    // |x| < 2^(-54)
    else if (hx < 0x3C900000) {
        if (hx < 0x00100000) {
            math.doNotOptimizeAway(@floatCast(f32, x));
        }
        return x;
    } else {
        k = 0;
    }

    const hfx = 0.5 * x;
    const hxs = x * hfx;
    const r1 = 1.0 + hxs * (Q1 + hxs * (Q2 + hxs * (Q3 + hxs * (Q4 + hxs * Q5))));
    const t = 3.0 - r1 * hfx;
    var e = hxs * ((r1 - t) / (6.0 - x * t));

    // c is 0
    if (k == 0) {
        return x - (x * e - hxs);
    }

    e = x * (e - c) - c;
    e -= hxs;

    // exp(x) ~ 2^k (x_reduced - e + 1)
    if (k == -1) {
        return 0.5 * (x - e) - 0.5;
    }
    if (k == 1) {
        if (x < -0.25) {
            return -2.0 * (e - (x + 0.5));
        } else {
            return 1.0 + 2.0 * (x - e);
        }
    }

    const twopk = @bitCast(f64, @intCast(u64, 0x3FF +% k) << 52);

    if (k < 0 or k > 56) {
        var y = x - e + 1.0;
        if (k == 1024) {
            y = y * 2.0 * 0x1.0p1023;
        } else {
            y = y * twopk;
        }

        return y - 1.0;
    }

    const uf = @bitCast(f64, @intCast(u64, 0x3FF -% k) << 52);
    if (k < 20) {
        return (x - e + (1 - uf)) * twopk;
    } else {
        return (x - (e + uf) + 1) * twopk;
    }
}

test "math.exp1m" {
    try expect(expm1(@as(f32, 0.0)) == expm1_32(0.0));
    try expect(expm1(@as(f64, 0.0)) == expm1_64(0.0));
}

test "math.expm1_32" {
    const epsilon = 0.000001;

    try expect(expm1_32(0.0) == 0.0);
    try expect(math.approxEqAbs(f32, expm1_32(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f32, expm1_32(0.2), 0.221403, epsilon));
    try expect(math.approxEqAbs(f32, expm1_32(0.8923), 1.440737, epsilon));
    try expect(math.approxEqAbs(f32, expm1_32(1.5), 3.481689, epsilon));
}

test "math.expm1_64" {
    const epsilon = 0.000001;

    try expect(expm1_64(0.0) == 0.0);
    try expect(math.approxEqAbs(f64, expm1_64(0.0), 0.0, epsilon));
    try expect(math.approxEqAbs(f64, expm1_64(0.2), 0.221403, epsilon));
    try expect(math.approxEqAbs(f64, expm1_64(0.8923), 1.440737, epsilon));
    try expect(math.approxEqAbs(f64, expm1_64(1.5), 3.481689, epsilon));
}

test "math.expm1_32.special" {
    const epsilon = 0.000001;

    try expect(math.isPositiveInf(expm1_32(math.inf(f32))));
    try expect(expm1_32(-math.inf(f32)) == -1.0);
    try expect(math.isNan(expm1_32(math.nan(f32))));
}

test "math.expm1_64.special" {
    const epsilon = 0.000001;

    try expect(math.isPositiveInf(expm1_64(math.inf(f64))));
    try expect(expm1_64(-math.inf(f64)) == -1.0);
    try expect(math.isNan(expm1_64(math.nan(f64))));
}

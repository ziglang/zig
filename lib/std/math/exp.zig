// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/expf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/exp.c

const std = @import("../std.zig");
const math = std.math;
const assert = std.debug.assert;
const builtin = @import("builtin");

/// Returns e raised to the power of x (e^x).
///
/// Special Cases:
///  - exp(+inf) = +inf
///  - exp(nan)  = nan
pub fn exp(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => exp32(x),
        f64 => exp64(x),
        else => @compileError("exp not implemented for " ++ @typeName(T)),
    };
}

fn exp32(x_: f32) f32 {
    const half = [_]f32{ 0.5, -0.5 };
    const ln2hi = 6.9314575195e-1;
    const ln2lo = 1.4286067653e-6;
    const invln2 = 1.4426950216e+0;
    const P1 = 1.6666625440e-1;
    const P2 = -2.7667332906e-3;

    var x = x_;
    var hx = @bitCast(u32, x);
    const sign = @intCast(i32, hx >> 31);
    hx &= 0x7FFFFFFF;

    if (math.isNan(x)) {
        return x;
    }

    // |x| >= -87.33655 or nan
    if (hx >= 0x42AEAC50) {
        // nan
        if (hx > 0x7F800000) {
            return x;
        }
        // x >= 88.722839
        if (hx >= 0x42b17218 and sign == 0) {
            return x * 0x1.0p127;
        }
        if (sign != 0) {
            math.doNotOptimizeAway(-0x1.0p-149 / x); // overflow
            // x <= -103.972084
            if (hx >= 0x42CFF1B5) {
                return 0;
            }
        }
    }

    var k: i32 = undefined;
    var hi: f32 = undefined;
    var lo: f32 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3EB17218) {
        // |x| > 1.5 * ln2
        if (hx > 0x3F851592) {
            k = @floatToInt(i32, invln2 * x + half[@intCast(usize, sign)]);
        } else {
            k = 1 - sign - sign;
        }

        const fk = @intToFloat(f32, k);
        hi = x - fk * ln2hi;
        lo = fk * ln2lo;
        x = hi - lo;
    }
    // |x| > 2^(-14)
    else if (hx > 0x39000000) {
        k = 0;
        hi = x;
        lo = 0;
    } else {
        math.doNotOptimizeAway(0x1.0p127 + x); // inexact
        return 1 + x;
    }

    const xx = x * x;
    const c = x - xx * (P1 + xx * P2);
    const y = 1 + (x * c / (2 - c) - lo + hi);

    if (k == 0) {
        return y;
    } else {
        return math.scalbn(y, k);
    }
}

fn exp64(x_: f64) f64 {
    const half = [_]f64{ 0.5, -0.5 };
    const ln2hi: f64 = 6.93147180369123816490e-01;
    const ln2lo: f64 = 1.90821492927058770002e-10;
    const invln2: f64 = 1.44269504088896338700e+00;
    const P1: f64 = 1.66666666666666019037e-01;
    const P2: f64 = -2.77777777770155933842e-03;
    const P3: f64 = 6.61375632143793436117e-05;
    const P4: f64 = -1.65339022054652515390e-06;
    const P5: f64 = 4.13813679705723846039e-08;

    var x = x_;
    var ux = @bitCast(u64, x);
    var hx = ux >> 32;
    const sign = @intCast(i32, hx >> 31);
    hx &= 0x7FFFFFFF;

    if (math.isNan(x)) {
        return x;
    }

    // |x| >= 708.39 or nan
    if (hx >= 0x4086232B) {
        // nan
        if (hx > 0x7FF00000) {
            return x;
        }
        if (x > 709.782712893383973096) {
            // overflow if x != inf
            if (!math.isInf(x)) {
                math.raiseOverflow();
            }
            return math.inf(f64);
        }
        if (x < -708.39641853226410622) {
            // underflow if x != -inf
            // math.doNotOptimizeAway(@as(f32, -0x1.0p-149 / x));
            if (x < -745.13321910194110842) {
                return 0;
            }
        }
    }

    // argument reduction
    var k: i32 = undefined;
    var hi: f64 = undefined;
    var lo: f64 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3EB17218) {
        // |x| >= 1.5 * ln2
        if (hx > 0x3FF0A2B2) {
            k = @floatToInt(i32, invln2 * x + half[@intCast(usize, sign)]);
        } else {
            k = 1 - sign - sign;
        }

        const dk = @intToFloat(f64, k);
        hi = x - dk * ln2hi;
        lo = dk * ln2lo;
        x = hi - lo;
    }
    // |x| > 2^(-28)
    else if (hx > 0x3E300000) {
        k = 0;
        hi = x;
        lo = 0;
    } else {
        // inexact if x != 0
        // math.doNotOptimizeAway(0x1.0p1023 + x);
        return 1 + x;
    }

    const xx = x * x;
    const c = x - xx * (P1 + xx * (P2 + xx * (P3 + xx * (P4 + xx * P5))));
    const y = 1 + (x * c / (2 - c) - lo + hi);

    if (k == 0) {
        return y;
    } else {
        return math.scalbn(y, k);
    }
}

test "math.exp" {
    assert(exp(@as(f32, 0.0)) == exp32(0.0));
    assert(exp(@as(f64, 0.0)) == exp64(0.0));
}

test "math.exp32" {
    const epsilon = 0.000001;

    assert(exp32(0.0) == 1.0);
    assert(math.approxEq(f32, exp32(0.0), 1.0, epsilon));
    assert(math.approxEq(f32, exp32(0.2), 1.221403, epsilon));
    assert(math.approxEq(f32, exp32(0.8923), 2.440737, epsilon));
    assert(math.approxEq(f32, exp32(1.5), 4.481689, epsilon));
}

test "math.exp64" {
    const epsilon = 0.000001;

    assert(exp64(0.0) == 1.0);
    assert(math.approxEq(f64, exp64(0.0), 1.0, epsilon));
    assert(math.approxEq(f64, exp64(0.2), 1.221403, epsilon));
    assert(math.approxEq(f64, exp64(0.8923), 2.440737, epsilon));
    assert(math.approxEq(f64, exp64(1.5), 4.481689, epsilon));
}

test "math.exp32.special" {
    assert(math.isPositiveInf(exp32(math.inf(f32))));
    assert(math.isNan(exp32(math.nan(f32))));
}

test "math.exp64.special" {
    assert(math.isPositiveInf(exp64(math.inf(f64))));
    assert(math.isNan(exp64(math.nan(f64))));
}

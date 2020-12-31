// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/tanhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/tanh.c

const builtin = @import("builtin");
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const expo2 = @import("expo2.zig").expo2;
const maxInt = std.math.maxInt;

/// Returns the hyperbolic tangent of x.
///
/// Special Cases:
///  - sinh(+-0)   = +-0
///  - sinh(+-inf) = +-1
///  - sinh(nan)   = nan
pub fn tanh(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => tanh32(x),
        f64 => tanh64(x),
        else => @compileError("tanh not implemented for " ++ @typeName(T)),
    };
}

// tanh(x) = (exp(x) - exp(-x)) / (exp(x) + exp(-x))
//         = (exp(2x) - 1) / (exp(2x) - 1 + 2)
//         = (1 - exp(-2x)) / (exp(-2x) - 1 + 2)
fn tanh32(x: f32) f32 {
    const u = @bitCast(u32, x);
    const ux = u & 0x7FFFFFFF;
    const ax = @bitCast(f32, ux);

    var t: f32 = undefined;

    if (x == 0.0 or math.isNan(x)) {
        return x;
    }

    // |x| < log(3) / 2 ~= 0.5493 or nan
    if (ux > 0x3F0C9F54) {
        // |x| > 10
        if (ux > 0x41200000) {
            t = 1.0;
        } else {
            t = math.expm1(2 * x);
            t = 1 - 2 / (t + 2);
        }
    }
    // |x| > log(5 / 3) / 2 ~= 0.2554
    else if (ux > 0x3E82C578) {
        t = math.expm1(2 * x);
        t = t / (t + 2);
    }
    // |x| >= 0x1.0p-126
    else if (ux >= 0x00800000) {
        t = math.expm1(-2 * x);
        t = -t / (t + 2);
    }
    // |x| is subnormal
    else {
        math.doNotOptimizeAway(x * x);
        t = x;
    }

    if (u >> 31 != 0) {
        return -t;
    } else {
        return t;
    }
}

fn tanh64(x: f64) f64 {
    const u = @bitCast(u64, x);
    const w = @intCast(u32, u >> 32);
    const ax = @bitCast(f64, u & (maxInt(u64) >> 1));

    var t: f64 = undefined;

    // TODO: Shouldn't need these checks.
    if (x == 0.0 or math.isNan(x)) {
        return x;
    }

    // |x| < log(3) / 2 ~= 0.5493 or nan
    if (w > 0x3FE193EA) {
        // |x| > 20 or nan
        if (w > 0x40340000) {
            t = 1.0;
        } else {
            t = math.expm1(2 * x);
            t = 1 - 2 / (t + 2);
        }
    }
    // |x| > log(5 / 3) / 2 ~= 0.2554
    else if (w > 0x3FD058AE) {
        t = math.expm1(2 * x);
        t = t / (t + 2);
    }
    // |x| >= 0x1.0p-1022
    else if (w >= 0x00100000) {
        t = math.expm1(-2 * x);
        t = -t / (t + 2);
    }
    // |x| is subnormal
    else {
        math.doNotOptimizeAway(@floatCast(f32, x));
        t = x;
    }

    if (u >> 63 != 0) {
        return -t;
    } else {
        return t;
    }
}

test "math.tanh" {
    expect(tanh(@as(f32, 1.5)) == tanh32(1.5));
    expect(tanh(@as(f64, 1.5)) == tanh64(1.5));
}

test "math.tanh32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, tanh32(0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f32, tanh32(0.2), 0.197375, epsilon));
    expect(math.approxEqAbs(f32, tanh32(0.8923), 0.712528, epsilon));
    expect(math.approxEqAbs(f32, tanh32(1.5), 0.905148, epsilon));
    expect(math.approxEqAbs(f32, tanh32(37.45), 1.0, epsilon));
}

test "math.tanh64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, tanh64(0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f64, tanh64(0.2), 0.197375, epsilon));
    expect(math.approxEqAbs(f64, tanh64(0.8923), 0.712528, epsilon));
    expect(math.approxEqAbs(f64, tanh64(1.5), 0.905148, epsilon));
    expect(math.approxEqAbs(f64, tanh64(37.45), 1.0, epsilon));
}

test "math.tanh32.special" {
    expect(tanh32(0.0) == 0.0);
    expect(tanh32(-0.0) == -0.0);
    expect(tanh32(math.inf(f32)) == 1.0);
    expect(tanh32(-math.inf(f32)) == -1.0);
    expect(math.isNan(tanh32(math.nan(f32))));
}

test "math.tanh64.special" {
    expect(tanh64(0.0) == 0.0);
    expect(tanh64(-0.0) == -0.0);
    expect(tanh64(math.inf(f64)) == 1.0);
    expect(tanh64(-math.inf(f64)) == -1.0);
    expect(math.isNan(tanh64(math.nan(f64))));
}

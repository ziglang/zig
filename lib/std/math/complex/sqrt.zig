// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csqrtf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csqrt.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the square root of z. The real and imaginary parts of the result have the same sign
/// as the imaginary part of z.
pub fn sqrt(z: anytype) @TypeOf(z) {
    const T = @TypeOf(z.re);

    return switch (T) {
        f32 => sqrt32(z),
        f64 => sqrt64(z),
        else => @compileError("sqrt not implemented for " ++ @typeName(T)),
    };
}

fn sqrt32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    if (x == 0 and y == 0) {
        return Complex(f32).new(0, y);
    }
    if (math.isInf(y)) {
        return Complex(f32).new(math.inf(f32), y);
    }
    if (math.isNan(x)) {
        // raise invalid if y is not nan
        const t = (y - y) / (y - y);
        return Complex(f32).new(x, t);
    }
    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        if (math.signbit(x)) {
            return Complex(f32).new(math.fabs(x - y), math.copysign(f32, x, y));
        } else {
            return Complex(f32).new(x, math.copysign(f32, y - y, y));
        }
    }

    // y = nan special case is handled fine below

    // double-precision avoids overflow with correct rounding.
    const dx = @as(f64, x);
    const dy = @as(f64, y);

    if (dx >= 0) {
        const t = math.sqrt((dx + math.hypot(f64, dx, dy)) * 0.5);
        return Complex(f32).new(
            @floatCast(f32, t),
            @floatCast(f32, dy / (2.0 * t)),
        );
    } else {
        const t = math.sqrt((-dx + math.hypot(f64, dx, dy)) * 0.5);
        return Complex(f32).new(
            @floatCast(f32, math.fabs(y) / (2.0 * t)),
            @floatCast(f32, math.copysign(f64, t, y)),
        );
    }
}

fn sqrt64(z: Complex(f64)) Complex(f64) {
    // may encounter overflow for im,re >= DBL_MAX / (1 + sqrt(2))
    const threshold = 0x1.a827999fcef32p+1022;

    var x = z.re;
    var y = z.im;

    if (x == 0 and y == 0) {
        return Complex(f64).new(0, y);
    }
    if (math.isInf(y)) {
        return Complex(f64).new(math.inf(f64), y);
    }
    if (math.isNan(x)) {
        // raise invalid if y is not nan
        const t = (y - y) / (y - y);
        return Complex(f64).new(x, t);
    }
    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        if (math.signbit(x)) {
            return Complex(f64).new(math.fabs(x - y), math.copysign(f64, x, y));
        } else {
            return Complex(f64).new(x, math.copysign(f64, y - y, y));
        }
    }

    // y = nan special case is handled fine below

    // scale to avoid overflow
    var scale = false;
    if (math.fabs(x) >= threshold or math.fabs(y) >= threshold) {
        x *= 0.25;
        y *= 0.25;
        scale = true;
    }

    var result: Complex(f64) = undefined;
    if (x >= 0) {
        const t = math.sqrt((x + math.hypot(f64, x, y)) * 0.5);
        result = Complex(f64).new(t, y / (2.0 * t));
    } else {
        const t = math.sqrt((-x + math.hypot(f64, x, y)) * 0.5);
        result = Complex(f64).new(math.fabs(y) / (2.0 * t), math.copysign(f64, t, y));
    }

    if (scale) {
        result.re *= 2;
        result.im *= 2;
    }

    return result;
}

const epsilon = 0.0001;

test "complex.csqrt32" {
    const a = Complex(f32).new(5, 3);
    const c = sqrt(a);

    testing.expect(math.approxEqAbs(f32, c.re, 2.327117, epsilon));
    testing.expect(math.approxEqAbs(f32, c.im, 0.644574, epsilon));
}

test "complex.csqrt64" {
    const a = Complex(f64).new(5, 3);
    const c = sqrt(a);

    testing.expect(math.approxEqAbs(f64, c.re, 2.3271175190399496, epsilon));
    testing.expect(math.approxEqAbs(f64, c.im, 0.6445742373246469, epsilon));
}

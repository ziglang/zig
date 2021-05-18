// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ctanhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ctanh.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the hyperbolic tangent of z.
pub fn tanh(z: anytype) @TypeOf(z) {
    const T = @TypeOf(z.re);
    return switch (T) {
        f32 => tanh32(z),
        f64 => tanh64(z),
        else => @compileError("tan not implemented for " ++ @typeName(z)),
    };
}

fn tanh32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const hx = @bitCast(u32, x);
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7f800000) {
        if (ix & 0x7fffff != 0) {
            const r = if (y == 0) y else x * y;
            return Complex(f32).init(x, r);
        }
        const xx = @bitCast(f32, hx - 0x40000000);
        const r = if (math.isInf(y)) y else math.sin(y) * math.cos(y);
        return Complex(f32).init(xx, math.copysign(f32, 0, r));
    }

    if (!math.isFinite(y)) {
        const r = if (ix != 0) y - y else x;
        return Complex(f32).init(r, y - y);
    }

    // x >= 11
    if (ix >= 0x41300000) {
        const exp_mx = math.exp(-math.fabs(x));
        return Complex(f32).init(math.copysign(f32, 1, x), 4 * math.sin(y) * math.cos(y) * exp_mx * exp_mx);
    }

    // Kahan's algorithm
    const t = math.tan(y);
    const beta = 1.0 + t * t;
    const s = math.sinh(x);
    const rho = math.sqrt(1 + s * s);
    const den = 1 + beta * s * s;

    return Complex(f32).init((beta * rho * s) / den, t / den);
}

fn tanh64(z: Complex(f64)) Complex(f64) {
    const x = z.re;
    const y = z.im;

    const fx = @bitCast(u64, x);
    // TODO: zig should allow this conversion implicitly because it can notice that the value necessarily
    // fits in range.
    const hx = @intCast(u32, fx >> 32);
    const lx = @truncate(u32, fx);
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7ff00000) {
        if ((ix & 0x7fffff) | lx != 0) {
            const r = if (y == 0) y else x * y;
            return Complex(f64).init(x, r);
        }

        const xx = @bitCast(f64, (@as(u64, hx - 0x40000000) << 32) | lx);
        const r = if (math.isInf(y)) y else math.sin(y) * math.cos(y);
        return Complex(f64).init(xx, math.copysign(f64, 0, r));
    }

    if (!math.isFinite(y)) {
        const r = if (ix != 0) y - y else x;
        return Complex(f64).init(r, y - y);
    }

    // x >= 22
    if (ix >= 0x40360000) {
        const exp_mx = math.exp(-math.fabs(x));
        return Complex(f64).init(math.copysign(f64, 1, x), 4 * math.sin(y) * math.cos(y) * exp_mx * exp_mx);
    }

    // Kahan's algorithm
    const t = math.tan(y);
    const beta = 1.0 + t * t;
    const s = math.sinh(x);
    const rho = math.sqrt(1 + s * s);
    const den = 1 + beta * s * s;

    return Complex(f64).init((beta * rho * s) / den, t / den);
}

const epsilon = 0.0001;

test "complex.ctanh32" {
    const a = Complex(f32).init(5, 3);
    const c = tanh(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 0.999913, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, -0.000025, epsilon));
}

test "complex.ctanh64" {
    const a = Complex(f64).init(5, 3);
    const c = tanh(a);

    try testing.expect(math.approxEqAbs(f64, c.re, 0.999913, epsilon));
    try testing.expect(math.approxEqAbs(f64, c.im, -0.000025, epsilon));
}

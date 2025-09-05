//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/csqrtf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/csqrt.c

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Calculates the square root of complex number. The real and imaginary parts of the result have the same sign
/// as the imaginary part of complex number.
pub fn sqrt(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    return switch (T) {
        f32 => sqrt32(z),
        f64 => sqrt64(z),
        else => @compileError("sqrt not implemented for " ++ @typeName(T)),
    };
}

fn sqrt32(z: Complex(f32)) Complex(f32) {
    const a = z.re;
    const b = z.im;

    if (a == 0 and b == 0)
        return .init(0, b);

    if (math.isInf(b))
        return .init(math.inf(f32), b);

    if (math.isNan(a)) {
        const t = (b - b) / (b - b); // Raise invalid if y is not nan

        return .init(a, t);
    }

    if (math.isInf(a)) {
        // sqrt(inf + i nan)  = inf + nan i
        // sqrt(inf + iy)     = inf + i0
        // sqrt(-inf + i nan) = nan +- inf i
        // sqrt(-inf + iy)    = 0 + inf i
        if (math.signbit(a))
            return .init(@abs(b - b), math.copysign(a, b))
        else
            return .init(a, math.copysign(b - b, b));
    }

    // y = nan special case is handled fine below

    // Double-precision avoids overflow with correct rounding
    const dx: f64 = a;
    const dy: f64 = b;

    if (dx >= 0) {
        const t = @sqrt((dx + math.hypot(dx, dy)) * 0.5);

        return .init(
            @floatCast(t),
            @floatCast(dy / (2.0 * t)),
        );
    } else {
        const t = @sqrt((-dx + math.hypot(dx, dy)) * 0.5);

        return .init(
            @floatCast(@abs(b) / (2.0 * t)),
            @floatCast(math.copysign(t, b)),
        );
    }
}

fn sqrt64(z: Complex(f64)) Complex(f64) {
    // May encounter overflow for im, re >= DBL_MAX / (1 + sqrt(2))
    const threshold = 0x1.a827999fcef32p+1022;

    var a = z.re;
    var b = z.im;

    if (a == 0 and b == 0)
        return .init(0, b);

    if (math.isInf(b))
        return .init(math.inf(f64), b);

    if (math.isNan(a)) {
        // Raise invalid if y is not nan
        const t = (b - b) / (b - b);

        return .init(a, t);
    }

    if (math.isInf(a)) {
        // sqrt(inf + i nan)  = inf + nan i
        // sqrt(inf + iy)     = inf + i0
        // sqrt(-inf + i nan) = nan +- inf i
        // sqrt(-inf + iy)    = 0 + inf i
        if (math.signbit(a))
            return .init(@abs(b - b), math.copysign(a, b))
        else
            return .init(a, math.copysign(b - b, b));
    }

    // y = nan special case is handled fine below

    // Scale to avoid overflow
    var scale = false;

    if (@abs(a) >= threshold or @abs(b) >= threshold) {
        a *= 0.25;
        b *= 0.25;

        scale = true;
    }

    var result: Complex(f64) = undefined;

    // Algorithm 312, CACM vol 10, Oct 1967
    if (a >= 0) {
        const t = @sqrt((a + math.hypot(a, b)) * 0.5);

        result = .init(t, b / (2 * t));
    } else {
        const t = @sqrt((-a + math.hypot(a, b)) * 0.5);

        result = .init(@abs(b) / (2 * t), math.copysign(t, b));
    }

    if (scale) { // Rescale
        result.re *= 2;
        result.im *= 2;
    }

    return result;
}

test sqrt32 {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const sqrt_a = sqrt(a);

    try testing.expectApproxEqAbs(2.3271174, sqrt_a.re, epsilon);
    try testing.expectApproxEqAbs(0.6445742, sqrt_a.im, epsilon);
}

test sqrt64 {
    const epsilon = math.floatEps(f64);

    const a: Complex(f64) = .init(5, 3);
    const sqrt_a = sqrt(a);

    try testing.expectApproxEqAbs(2.3271175190399496, sqrt_a.re, epsilon);
    try testing.expectApproxEqAbs(0.6445742373246469, sqrt_a.im, epsilon);
}

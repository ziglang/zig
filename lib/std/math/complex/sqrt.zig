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
pub fn sqrt(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

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
        return Complex(f32).init(0, y);
    }
    if (math.isInf(y)) {
        return Complex(f32).init(math.inf(f32), y);
    }
    if (math.isNan(x)) {
        // raise invalid if y is not nan
        const t = (y - y) / (y - y);
        return Complex(f32).init(x, t);
    }
    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        if (math.signbit(x)) {
            return Complex(f32).init(@abs(y - y), math.copysign(x, y));
        } else {
            return Complex(f32).init(x, math.copysign(y - y, y));
        }
    }

    // y = nan special case is handled fine below

    // double-precision avoids overflow with correct rounding.
    const dx = @as(f64, x);
    const dy = @as(f64, y);

    if (dx >= 0) {
        const t = @sqrt((dx + math.hypot(dx, dy)) * 0.5);
        return Complex(f32).init(
            @as(f32, @floatCast(t)),
            @as(f32, @floatCast(dy / (2.0 * t))),
        );
    } else {
        const t = @sqrt((-dx + math.hypot(dx, dy)) * 0.5);
        return Complex(f32).init(
            @as(f32, @floatCast(@abs(y) / (2.0 * t))),
            @as(f32, @floatCast(math.copysign(t, y))),
        );
    }
}

fn sqrt64(z: Complex(f64)) Complex(f64) {
    // may encounter overflow for im,re >= DBL_MAX / (1 + sqrt(2))
    const threshold = 0x1.a827999fcef32p+1022;

    var x = z.re;
    var y = z.im;

    if (x == 0 and y == 0) {
        return Complex(f64).init(0, y);
    }
    if (math.isInf(y)) {
        return Complex(f64).init(math.inf(f64), y);
    }
    if (math.isNan(x)) {
        // raise invalid if y is not nan
        const t = (y - y) / (y - y);
        return Complex(f64).init(x, t);
    }
    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        if (math.signbit(x)) {
            return Complex(f64).init(@abs(y - y), math.copysign(x, y));
        } else {
            return Complex(f64).init(x, math.copysign(y - y, y));
        }
    }

    // y = nan special case is handled fine below

    // scale to avoid overflow
    var scale = false;
    if (@abs(x) >= threshold or @abs(y) >= threshold) {
        x *= 0.25;
        y *= 0.25;
        scale = true;
    }

    var result: Complex(f64) = undefined;
    if (x >= 0) {
        const t = @sqrt((x + math.hypot(x, y)) * 0.5);
        result = Complex(f64).init(t, y / (2.0 * t));
    } else {
        const t = @sqrt((-x + math.hypot(x, y)) * 0.5);
        result = Complex(f64).init(@abs(y) / (2.0 * t), math.copysign(t, y));
    }

    if (scale) {
        result.re *= 2;
        result.im *= 2;
    }

    return result;
}

test sqrt32 {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = sqrt(a);

    try testing.expectApproxEqAbs(2.3271174, c.re, epsilon);
    try testing.expectApproxEqAbs(0.6445742, c.im, epsilon);
}

test sqrt64 {
    const epsilon = math.floatEps(f64);
    const a = Complex(f64).init(5, 3);
    const c = sqrt(a);

    try testing.expectApproxEqAbs(2.3271175190399496, c.re, epsilon);
    try testing.expectApproxEqAbs(0.6445742373246469, c.im, epsilon);
}

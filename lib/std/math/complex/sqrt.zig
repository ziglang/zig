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

    if (x == 0 and y == 0) return .{
        .re = 0,
        .im = y,
    };

    if (math.isInf(y)) return .{
        .re = math.inf(f32),
        .im = y,
    };

    if (math.isNan(x)) return .{
        .re = x,
        .im = (y - y) / (y - y), // raise invalid if y is not nan
    };

    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        return if (math.signbit(x)) .{
            .re = @abs(x - y),
            .im = math.copysign(x, y),
        } else .{
            .re = x,
            .im = math.copysign(y - y, y),
        };
    }

    // y = nan special case is handled fine below

    // double-precision avoids overflow with correct rounding.
    const dx: f64 = x;
    const dy: f64 = y;

    if (dx >= 0) {
        const t = @sqrt(0.5 * (math.hypot(dx, dy) + dx));
        return .{
            .re = @floatCast(t),
            .im = @floatCast(dy / (2.0 * t)),
        };
    } else {
        const t = @sqrt(0.5 * (math.hypot(dx, dy) - dx));
        return .{
            .re = @floatCast(@abs(y) / (2.0 * t)),
            .im = @floatCast(math.copysign(t, y)),
        };
    }
}

fn sqrt64(z: Complex(f64)) Complex(f64) {
    // may encounter overflow for im,re >= DBL_MAX / (1 + sqrt(2))
    const threshold = 0x1.a827999fcef32p+1022;

    var x = z.re;
    var y = z.im;

    if (x == 0 and y == 0) return .{
        .re = 0,
        .im = y,
    };

    if (math.isInf(y)) return .{
        .re = math.inf(f64),
        .im = y,
    };

    if (math.isNan(x)) return .{
        .re = x,
        .im = (y - y) / (y - y), // raise invalid if y is not nan
    };

    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        return if (math.signbit(x)) .{
            .re = @abs(x - y),
            .im = math.copysign(x, y),
        } else .{
            .re = x,
            .im = math.copysign(y - y, y),
        };
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
        const t = @sqrt(0.5 * (math.hypot(x, y) + x));
        result.re = t;
        result.im = y / (2.0 * t);
    } else {
        const t = @sqrt(0.5 * (math.hypot(x, y) - x));
        result.re = @abs(y) / (2.0 * t);
        result.im = math.copysign(t, y);
    }

    if (scale) {
        result.re *= 2;
        result.im *= 2;
    }

    return result;
}

const epsilon = 0.0001;

test sqrt32 {
    const a = Complex(f32).init(5, 3);
    const c = sqrt(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 2.327117, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 0.644574, epsilon));
}

test sqrt64 {
    const a = Complex(f64).init(5, 3);
    const c = sqrt(a);

    try testing.expect(math.approxEqAbs(f64, c.re, 2.3271175190399496, epsilon));
    try testing.expect(math.approxEqAbs(f64, c.im, 0.6445742373246469, epsilon));
}

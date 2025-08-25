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
pub fn tanh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    return switch (T) {
        f32 => tanh32(z),
        f64 => tanh64(z),
        else => @compileError("tan not implemented for " ++ @typeName(z)),
    };
}

fn tanh32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const hx = @as(u32, @bitCast(x));
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7f800000) {
        if (ix & 0x7fffff != 0) {
            const r = if (y == 0) y else x * y;
            return Complex(f32).init(x, r);
        }
        const xx = @as(f32, @bitCast(hx - 0x40000000));
        const r = if (math.isInf(y)) y else @sin(y) * @cos(y);
        return Complex(f32).init(xx, math.copysign(@as(f32, 0.0), r));
    }

    if (!math.isFinite(y)) {
        const r = if (ix != 0) y - y else x;
        return Complex(f32).init(r, y - y);
    }

    // x >= 11
    if (ix >= 0x41300000) {
        const exp_mx = @exp(-@abs(x));
        return Complex(f32).init(math.copysign(@as(f32, 1.0), x), 4 * @sin(y) * @cos(y) * exp_mx * exp_mx);
    }

    // Kahan's algorithm
    const t = @tan(y);
    const beta = 1.0 + t * t;
    const s = math.sinh(x);
    const rho = @sqrt(1 + s * s);
    const den = 1 + beta * s * s;

    return Complex(f32).init((beta * rho * s) / den, t / den);
}

fn tanh64(z: Complex(f64)) Complex(f64) {
    const x = z.re;
    const y = z.im;

    const fx: u64 = @bitCast(x);
    // TODO: zig should allow this conversion implicitly because it can notice that the value necessarily
    // fits in range.
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7ff00000) {
        if ((ix & 0xfffff) | lx != 0) {
            const r = if (y == 0) y else x * y;
            return Complex(f64).init(x, r);
        }

        const xx: f64 = @bitCast((@as(u64, hx - 0x40000000) << 32) | lx);
        const r = if (math.isInf(y)) y else @sin(y) * @cos(y);
        return Complex(f64).init(xx, math.copysign(@as(f64, 0.0), r));
    }

    if (!math.isFinite(y)) {
        const r = if (ix != 0) y - y else x;
        return Complex(f64).init(r, y - y);
    }

    // x >= 22
    if (ix >= 0x40360000) {
        const exp_mx = @exp(-@abs(x));
        return Complex(f64).init(math.copysign(@as(f64, 1.0), x), 4 * @sin(y) * @cos(y) * exp_mx * exp_mx);
    }

    // Kahan's algorithm
    const t = @tan(y);
    const beta = 1.0 + t * t;
    const s = math.sinh(x);
    const rho = @sqrt(1 + s * s);
    const den = 1 + beta * s * s;

    return Complex(f64).init((beta * rho * s) / den, t / den);
}

test tanh32 {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = tanh(a);

    try testing.expectApproxEqAbs(0.99991274, c.re, epsilon);
    try testing.expectApproxEqAbs(-0.00002536878, c.im, epsilon);
}

test tanh64 {
    const epsilon = math.floatEps(f64);
    const a = Complex(f64).init(5, 3);
    const c = tanh(a);

    try testing.expectApproxEqAbs(0.9999128201513536, c.re, epsilon);
    try testing.expectApproxEqAbs(-0.00002536867620767604, c.im, epsilon);
}

test "tanh64 musl" {
    const epsilon = math.floatEps(f64);
    const a = Complex(f64).init(std.math.inf(f64), std.math.inf(f64));
    const c = tanh(a);

    try testing.expectApproxEqAbs(1, c.re, epsilon);
    try testing.expectApproxEqAbs(0, c.im, epsilon);
}

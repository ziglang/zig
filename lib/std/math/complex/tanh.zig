//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/ctanhf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/ctanh.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Calculates the hyperbolic tangent of complex number.
pub fn tanh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    return switch (T) {
        f32 => tanh32(z),
        f64 => tanh64(z),
        else => @compileError("tanh not implemented for " ++ @typeName(T)),
    };
}

fn tanh32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const hx: u32 = @bitCast(x);
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7f800000) {
        if (ix & 0x7fffff != 0)
            return .init(x, if (y == 0) y else x * y);

        return .init(
            @bitCast(hx - 0x40000000),
            math.copysign(
                @as(f32, 0),
                if (math.isInf(y))
                    y
                else
                    @sin(y) * @cos(y),
            ),
        );
    }

    if (!math.isFinite(y))
        return .init(
            if (ix != 0)
                y - y
            else
                x,
            y - y,
        );

    if (ix >= 0x41300000) { // x >= 11
        const exp_mx = @exp(-@abs(x));

        return .init(
            math.copysign(@as(f32, 1), x),
            4 * @sin(y) * @cos(y) * exp_mx * exp_mx,
        );
    }

    const t = @tan(y);
    const beta = 1.0 + t * t;
    const s = math.sinh(x);
    const rho = @sqrt(1 + s * s);
    const den = 1 + beta * s * s;

    return .init(
        (beta * rho * s) / den,
        t / den,
    );
}

fn tanh64(z: Complex(f64)) Complex(f64) {
    const x = z.re;
    const y = z.im;

    const fx: u64 = @bitCast(x);
    // TODO: zig should allow this conversion implicitly because it can notice that the value necessarily
    // fits in range
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7ff00000) {
        if (((ix & 0xfffff) | lx) != 0)
            return .init(x, if (y == 0) y else x * y);

        return .init(
            @bitCast((@as(u64, hx - 0x40000000) << 32) | lx),
            math.copysign(
                @as(f64, 0),
                if (math.isInf(y))
                    y
                else
                    @sin(y) * @cos(y),
            ),
        );
    }

    if (!math.isFinite(y))
        return .init(
            if (ix != 0)
                y - y
            else
                x,
            y - y,
        );

    if (ix >= 0x40360000) { // x >= 22
        const exp_mx = @exp(-@abs(x));

        return .init(
            math.copysign(@as(f64, 1), x),
            4 * @sin(y) * @cos(y) * exp_mx * exp_mx,
        );
    }

    // Kahan's algorithm
    const t = @tan(y);
    const beta = 1.0 + t * t; // = 1 / cos^2(y)
    const s = math.sinh(x);
    const rho = @sqrt(1 + s * s); // = cosh(x)
    const den = 1 + beta * s * s;

    return .init(
        (beta * rho * s) / den,
        t / den,
    );
}

test tanh32 {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const tanh_a = tanh(a);

    try testing.expectApproxEqAbs(0.99991274, tanh_a.re, epsilon);
    try testing.expectApproxEqAbs(-0.00002536878, tanh_a.im, epsilon);
}

test tanh64 {
    const epsilon = math.floatEps(f64);

    const a: Complex(f64) = .init(5, 3);
    const tanh_a = tanh(a);

    try testing.expectApproxEqAbs(0.9999128201513536, tanh_a.re, epsilon);
    try testing.expectApproxEqAbs(-0.00002536867620767604, tanh_a.im, epsilon);
}

test "tanh64 musl" {
    const epsilon = math.floatEps(f64);

    const a: Complex(f64) = .init(
        math.inf(f64),
        math.inf(f64),
    );
    const tanh_a = tanh(a);

    try testing.expectApproxEqAbs(1.0, tanh_a.re, epsilon);
    try testing.expectApproxEqAbs(0.0, tanh_a.im, epsilon);
}

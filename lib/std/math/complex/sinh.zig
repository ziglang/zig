//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/csinhf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/csinh.c

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const ldexp = @import("ldexp.zig").ldexp;

/// Calculates the hyperbolic sine of complex number.
pub fn sinh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    return switch (T) {
        f32 => sinh32(z),
        f64 => sinh64(z),
        else => @compileError("sinh not implemented for " ++ @typeName(T)),
    };
}

fn sinh32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const hx: u32 = @bitCast(x);
    const ix = hx & 0x7fffffff;

    const hy: u32 = @bitCast(y);
    const iy = hy & 0x7fffffff;

    if (ix < 0x7f800000 and iy < 0x7f800000) {
        if (iy == 0)
            return .init(math.sinh(x), y);

        if (ix < 0x41100000) // Small x: normal case
            return .init(
                math.sinh(x) * @cos(y),
                math.cosh(x) * @sin(y),
            );

        // |x|>= 9, so cosh(x) ~= exp(|x|)
        if (ix < 0x42b17218) {
            // x < 88.7: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;

            return .init(
                math.copysign(h, x) * @cos(y),
                h * @sin(y),
            );
        }
        // x < 192.7: scale to avoid overflow
        else if (ix < 0x4340b1e7) {
            const v: Complex(f32) = .init(@abs(x), y);
            const r = ldexp(v, -1);

            return .init(r.re * math.copysign(@as(f32, 1), x), r.im);
        }
        // x >= 192.7: result always overflows
        else {
            const h = 0x1p127 * x;

            return .init(
                h * @cos(y),
                h * h * @sin(y),
            );
        }
    }

    if (ix == 0 and iy >= 0x7f800000)
        return .init(math.copysign(@as(f32, 0), x * (y - y)), y - y);

    if (iy == 0 and ix >= 0x7f800000) {
        if ((hx & 0x7fffff) == 0)
            return .init(x, y);

        return .init(x, math.copysign(@as(f32, 0), y));
    }

    if (ix < 0x7f800000 and iy >= 0x7f800000)
        return .init(y - y, x * (y - y));

    if (ix >= 0x7f800000 and (hx & 0x7fffff) == 0) {
        if (iy >= 0x7f800000)
            return .init(x * x, x * (y - y));

        return .init(
            x * @cos(y),
            math.inf(f32) * @sin(y),
        );
    }

    return .init(
        (x * x) * (y - y),
        (x + x) * (y - y),
    );
}

fn sinh64(z: Complex(f64)) Complex(f64) {
    const x = z.re;
    const y = z.im;

    const fx: u64 = @bitCast(x);
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);

    const fy: u64 = @bitCast(y);
    const hy: u32 = @intCast(fy >> 32);
    const ly: u32 = @truncate(fy);

    const ix = hx & 0x7fffffff;
    const iy = hy & 0x7fffffff;

    if (ix < 0x7ff00000 and iy < 0x7ff00000) {
        if ((iy | ly) == 0)
            return .init(math.sinh(x), y);

        if (ix < 0x40360000) // Small x: normal case
            return .init(
                math.sinh(x) * @cos(y),
                math.cosh(x) * @sin(y),
            );

        // |x|>= 22, so cosh(x) ~= exp(|x|)
        if (ix < 0x40862e42) {
            // x < 710: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;

            return .init(
                math.copysign(h, x) * @cos(y),
                h * @sin(y),
            );
        }
        // x < 1455: scale to avoid overflow
        else if (ix < 0x4096bbaa) {
            const v: Complex(f64) = .init(@abs(x), y);
            const r = ldexp(v, -1);

            return .init(r.re * math.copysign(@as(f64, 1), x), r.im);
        }
        // x >= 1455: result always overflows
        else {
            const h = 0x1p1023 * x;

            return .init(
                h * @cos(y),
                h * h * @sin(y),
            );
        }
    }

    if ((ix | lx) == 0 and iy >= 0x7ff00000)
        return .init(math.copysign(@as(f64, 0), x * (y - y)), y - y);

    if ((iy | ly) == 0 and ix >= 0x7ff00000) {
        if (((hx & 0xfffff) | lx) == 0)
            return .init(x, y);

        return .init(x, math.copysign(@as(f64, 0), y));
    }

    if (ix < 0x7ff00000 and iy >= 0x7ff00000)
        return .init(y - y, x * (y - y));

    if (ix >= 0x7ff00000 and ((hx & 0xfffff) | lx) == 0) {
        if (iy >= 0x7ff00000)
            return .init(x * x, x * (y - y));

        return .init(
            x * @cos(y),
            math.inf(f64) * @sin(y),
        );
    }

    return .init(
        (x * x) * (y - y),
        (x + x) * (y - y),
    );
}

test sinh32 {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const sinh_a = sinh(a);

    try testing.expectApproxEqAbs(-73.460617, sinh_a.re, epsilon);
    try testing.expectApproxEqAbs(10.472508, sinh_a.im, epsilon);
}

test sinh64 {
    const epsilon = math.floatEps(f64);

    const a: Complex(f64) = .init(5, 3);
    const sinh_a = sinh(a);

    try testing.expectApproxEqAbs(-73.46062169567367, sinh_a.re, epsilon);
    try testing.expectApproxEqAbs(10.472508533940392, sinh_a.im, epsilon);
}

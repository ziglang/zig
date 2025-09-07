//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/cexpf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/cexp.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const ldexp = @import("ldexp.zig").ldexp;

/// Calculates e raised to the power of complex number.
pub fn exp(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    return switch (T) {
        f32 => exp32(z),
        f64 => exp64(z),
        else => @compileError("exp not implemented for " ++ @typeName(T)),
    };
}

fn exp32(z: Complex(f32)) Complex(f32) {
    const exp_overflow = 0x42b17218; // max_exp * ln2 ~= 88.72283955
    const cexp_overflow = 0x43400074; // (max_exp - min_denom_exp) * ln2

    const x = z.re;
    const y = z.im;

    const hy = @as(u32, @bitCast(y)) & 0x7fffffff;

    if (hy == 0) // cexp(x + i0) = exp(x) + i0
        return .init(@exp(x), y);

    const hx = @as(u32, @bitCast(x));

    if ((hx & 0x7fffffff) == 0) // cexp(0 + iy) = cos(y) + isin(y)
        return .init(
            @cos(y),
            @sin(y),
        );

    if (hy >= 0x7f800000) {
        if ((hx & 0x7fffffff) != 0x7f800000)
            return .init(y - y, y - y) // cexp(finite|nan +- i inf|nan) = nan + i nan
        else if (hx & 0x80000000 != 0)
            return .init(0, 0) // cexp(-inf +- i inf|nan) = 0 + i0
        else
            return .init(x, y - y); // cexp(+inf +- i inf|nan) = inf + i nan
    }

    if (hx >= exp_overflow and hx <= cexp_overflow) {
        // x is between 88.7 and 192, so we must scale to avoid
        // overflow in exp(x)

        return ldexp(z, 0);
    } else {
        // Cases covered here:
        //  - x < exp_overflow => exp(x) won't overflow (common)
        //  - x > cexp_overflow, so exp(x) * s overflows for s > 0
        //  - x = +-inf
        //  - x = nan

        const exp_x = @exp(x);

        return .init(
            exp_x * @cos(y),
            exp_x * @sin(y),
        );
    }
}

fn exp64(z: Complex(f64)) Complex(f64) {
    const exp_overflow = 0x40862e42; // High bits of max_exp * ln2 ~= 710
    const cexp_overflow = 0x4096b8e4; // (max_exp - min_denorm_exp) * ln2

    const x = z.re;
    const y = z.im;

    const fy: u64 = @bitCast(y);
    const hy: u32 = @intCast((fy >> 32) & 0x7fffffff);
    const ly: u32 = @truncate(fy);

    if (hy | ly == 0) // cexp(x + i0) = exp(x) + i0
        return .init(@exp(x), y);

    const fx: u64 = @bitCast(x);
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);

    if ((hx & 0x7fffffff) | lx == 0) // cexp(0 + iy) = cos(y) + isin(y)
        return .init(
            @cos(y),
            @sin(y),
        );

    if (hy >= 0x7ff00000) {
        if (lx != 0 or (hx & 0x7fffffff) != 0x7ff00000)
            return .init(y - y, y - y) // cexp(finite|nan +- i inf|nan) = nan + i nan
        else if (hx & 0x80000000 != 0)
            return .init(0, 0) // cexp(-inf +- i inf|nan) = 0 + i0
        else
            return .init(x, y - y); // cexp(+inf +- i inf|nan) = inf + i nan
    }

    if (hx >= exp_overflow and hx <= cexp_overflow) {
        // x is between 709.7 and 1454.3, so we must scale to avoid
        // overflow in exp(x)

        return ldexp(z, 0);
    } else {
        // Cases covered here:
        //  - x < exp_overflow => exp(x) won't overflow (common)
        //  - x > cexp_overflow, so exp(x) * s overflows for s > 0
        //  - x = +-inf
        //  - x = nan

        const exp_x = @exp(x);

        return .init(
            exp_x * @cos(y),
            exp_x * @sin(y),
        );
    }
}

test exp32 {
    const tolerance_f32 = @sqrt(math.floatEps(f32));

    {
        const a: Complex(f32) = .init(5, 3);
        const exp_a = exp(a);

        try testing.expectApproxEqRel(@as(f32, -1.46927917e+02), exp_a.re, tolerance_f32);
        try testing.expectApproxEqRel(@as(f32, 2.0944065e+01), exp_a.im, tolerance_f32);
    }

    {
        const a: Complex(f32) = .init(88.8, 0x1p-149);
        const exp_a = exp(a);

        try testing.expectApproxEqAbs(math.inf(f32), exp_a.re, tolerance_f32);
        try testing.expectApproxEqAbs(@as(f32, 5.15088629e-07), exp_a.im, tolerance_f32);
    }
}

test exp64 {
    const tolerance_f64 = @sqrt(math.floatEps(f64));

    {
        const a: Complex(f64) = .init(5, 3);
        const exp_a = exp(a);

        try testing.expectApproxEqRel(@as(f64, -1.469279139083189e+02), exp_a.re, tolerance_f64);
        try testing.expectApproxEqRel(@as(f64, 2.094406620874596e+01), exp_a.im, tolerance_f64);
    }

    {
        const a: Complex(f64) = .init(709.8, 0x1p-1074);
        const exp_a = exp(a);

        try testing.expectApproxEqAbs(math.inf(f64), exp_a.re, tolerance_f64);
        try testing.expectApproxEqAbs(@as(f64, 9.036659362159884e-16), exp_a.im, tolerance_f64);
    }
}

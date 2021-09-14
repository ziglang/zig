// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/cexpf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/cexp.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

const ldexp_cexp = @import("ldexp.zig").ldexp_cexp;

/// Returns e raised to the power of z (e^z).
pub fn exp(z: anytype) @TypeOf(z) {
    const T = @TypeOf(z.re);

    return switch (T) {
        f32 => exp32(z),
        f64 => exp64(z),
        else => @compileError("exp not implemented for " ++ @typeName(z)),
    };
}

fn exp32(z: Complex(f32)) Complex(f32) {
    const exp_overflow = 0x42b17218; // max_exp * ln2 ~= 88.72283955
    const cexp_overflow = 0x43400074; // (max_exp - min_denom_exp) * ln2

    const x = z.re;
    const y = z.im;

    const hy = @bitCast(u32, y) & 0x7fffffff;
    // cexp(x + i0) = exp(x) + i0
    if (hy == 0) {
        return Complex(f32).init(math.exp(x), y);
    }

    const hx = @bitCast(u32, x);
    // cexp(0 + iy) = cos(y) + isin(y)
    if ((hx & 0x7fffffff) == 0) {
        return Complex(f32).init(math.cos(y), math.sin(y));
    }

    if (hy >= 0x7f800000) {
        // cexp(finite|nan +- i inf|nan) = nan + i nan
        if ((hx & 0x7fffffff) != 0x7f800000) {
            return Complex(f32).init(y - y, y - y);
        } // cexp(-inf +- i inf|nan) = 0 + i0
        else if (hx & 0x80000000 != 0) {
            return Complex(f32).init(0, 0);
        } // cexp(+inf +- i inf|nan) = inf + i nan
        else {
            return Complex(f32).init(x, y - y);
        }
    }

    // 88.7 <= x <= 192 so must scale
    if (hx >= exp_overflow and hx <= cexp_overflow) {
        return ldexp_cexp(z, 0);
    } // - x < exp_overflow => exp(x) won't overflow (common)
    // - x > cexp_overflow, so exp(x) * s overflows for s > 0
    // - x = +-inf
    // - x = nan
    else {
        const exp_x = math.exp(x);
        return Complex(f32).init(exp_x * math.cos(y), exp_x * math.sin(y));
    }
}

fn exp64(z: Complex(f64)) Complex(f64) {
    const exp_overflow = 0x40862e42; // high bits of max_exp * ln2 ~= 710
    const cexp_overflow = 0x4096b8e4; // (max_exp - min_denorm_exp) * ln2

    const x = z.re;
    const y = z.im;

    const fy = @bitCast(u64, y);
    const hy = @intCast(u32, (fy >> 32) & 0x7fffffff);
    const ly = @truncate(u32, fy);

    // cexp(x + i0) = exp(x) + i0
    if (hy | ly == 0) {
        return Complex(f64).init(math.exp(x), y);
    }

    const fx = @bitCast(u64, x);
    const hx = @intCast(u32, fx >> 32);
    const lx = @truncate(u32, fx);

    // cexp(0 + iy) = cos(y) + isin(y)
    if ((hx & 0x7fffffff) | lx == 0) {
        return Complex(f64).init(math.cos(y), math.sin(y));
    }

    if (hy >= 0x7ff00000) {
        // cexp(finite|nan +- i inf|nan) = nan + i nan
        if (lx != 0 or (hx & 0x7fffffff) != 0x7ff00000) {
            return Complex(f64).init(y - y, y - y);
        } // cexp(-inf +- i inf|nan) = 0 + i0
        else if (hx & 0x80000000 != 0) {
            return Complex(f64).init(0, 0);
        } // cexp(+inf +- i inf|nan) = inf + i nan
        else {
            return Complex(f64).init(x, y - y);
        }
    }

    // 709.7 <= x <= 1454.3 so must scale
    if (hx >= exp_overflow and hx <= cexp_overflow) {
        return ldexp_cexp(z, 0);
    } // - x < exp_overflow => exp(x) won't overflow (common)
    // - x > cexp_overflow, so exp(x) * s overflows for s > 0
    // - x = +-inf
    // - x = nan
    else {
        const exp_x = math.exp(x);
        return Complex(f64).init(exp_x * math.cos(y), exp_x * math.sin(y));
    }
}

test "complex.cexp32" {
    const tolerance_f32 = math.sqrt(math.epsilon(f32));

    {
        const a = Complex(f32).init(5, 3);
        const c = exp(a);

        try testing.expectApproxEqRel(@as(f32, -1.46927917e+02), c.re, tolerance_f32);
        try testing.expectApproxEqRel(@as(f32, 2.0944065e+01), c.im, tolerance_f32);
    }

    {
        const a = Complex(f32).init(88.8, 0x1p-149);
        const c = exp(a);

        try testing.expectApproxEqAbs(math.inf(f32), c.re, tolerance_f32);
        try testing.expectApproxEqAbs(@as(f32, 5.15088629e-07), c.im, tolerance_f32);
    }
}

test "complex.cexp64" {
    const tolerance_f64 = math.sqrt(math.epsilon(f64));

    {
        const a = Complex(f64).init(5, 3);
        const c = exp(a);

        try testing.expectApproxEqRel(@as(f64, -1.469279139083189e+02), c.re, tolerance_f64);
        try testing.expectApproxEqRel(@as(f64, 2.094406620874596e+01), c.im, tolerance_f64);
    }

    {
        const a = Complex(f64).init(709.8, 0x1p-1074);
        const c = exp(a);

        try testing.expectApproxEqAbs(math.inf(f64), c.re, tolerance_f64);
        try testing.expectApproxEqAbs(@as(f64, 9.036659362159884e-16), c.im, tolerance_f64);
    }
}

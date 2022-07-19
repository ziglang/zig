// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csinhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csinh.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

const ldexp_cexp = @import("ldexp.zig").ldexp_cexp;

/// Returns the hyperbolic sine of z.
pub fn sinh(z: anytype) @TypeOf(z) {
    const T = @TypeOf(z.re);
    return switch (T) {
        f32 => sinh32(z),
        f64 => sinh64(z),
        else => @compileError("tan not implemented for " ++ @typeName(z)),
    };
}

fn sinh32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const hx = @bitCast(u32, x);
    const ix = hx & 0x7fffffff;

    const hy = @bitCast(u32, y);
    const iy = hy & 0x7fffffff;

    if (ix < 0x7f800000 and iy < 0x7f800000) {
        if (iy == 0) {
            return Complex(f32).init(math.sinh(x), y);
        }
        // small x: normal case
        if (ix < 0x41100000) {
            return Complex(f32).init(math.sinh(x) * @cos(y), math.cosh(x) * @sin(y));
        }

        // |x|>= 9, so cosh(x) ~= exp(|x|)
        if (ix < 0x42b17218) {
            // x < 88.7: exp(|x|) won't overflow
            const h = @exp(@fabs(x)) * 0.5;
            return Complex(f32).init(math.copysign(h, x) * @cos(y), h * @sin(y));
        }
        // x < 192.7: scale to avoid overflow
        else if (ix < 0x4340b1e7) {
            const v = Complex(f32).init(@fabs(x), y);
            const r = ldexp_cexp(v, -1);
            return Complex(f32).init(r.re * math.copysign(@as(f32, 1.0), x), r.im);
        }
        // x >= 192.7: result always overflows
        else {
            const h = 0x1p127 * x;
            return Complex(f32).init(h * @cos(y), h * h * @sin(y));
        }
    }

    if (ix == 0 and iy >= 0x7f800000) {
        return Complex(f32).init(math.copysign(@as(f32, 0.0), x * (y - y)), y - y);
    }

    if (iy == 0 and ix >= 0x7f800000) {
        if (hx & 0x7fffff == 0) {
            return Complex(f32).init(x, y);
        }
        return Complex(f32).init(x, math.copysign(@as(f32, 0.0), y));
    }

    if (ix < 0x7f800000 and iy >= 0x7f800000) {
        return Complex(f32).init(y - y, x * (y - y));
    }

    if (ix >= 0x7f800000 and (hx & 0x7fffff) == 0) {
        if (iy >= 0x7f800000) {
            return Complex(f32).init(x * x, x * (y - y));
        }
        return Complex(f32).init(x * @cos(y), math.inf(f32) * @sin(y));
    }

    return Complex(f32).init((x * x) * (y - y), (x + x) * (y - y));
}

fn sinh64(z: Complex(f64)) Complex(f64) {
    const x = z.re;
    const y = z.im;

    const fx = @bitCast(u64, x);
    const hx = @intCast(u32, fx >> 32);
    const lx = @truncate(u32, fx);
    const ix = hx & 0x7fffffff;

    const fy = @bitCast(u64, y);
    const hy = @intCast(u32, fy >> 32);
    const ly = @truncate(u32, fy);
    const iy = hy & 0x7fffffff;

    if (ix < 0x7ff00000 and iy < 0x7ff00000) {
        if (iy | ly == 0) {
            return Complex(f64).init(math.sinh(x), y);
        }
        // small x: normal case
        if (ix < 0x40360000) {
            return Complex(f64).init(math.sinh(x) * @cos(y), math.cosh(x) * @sin(y));
        }

        // |x|>= 22, so cosh(x) ~= exp(|x|)
        if (ix < 0x40862e42) {
            // x < 710: exp(|x|) won't overflow
            const h = @exp(@fabs(x)) * 0.5;
            return Complex(f64).init(math.copysign(h, x) * @cos(y), h * @sin(y));
        }
        // x < 1455: scale to avoid overflow
        else if (ix < 0x4096bbaa) {
            const v = Complex(f64).init(@fabs(x), y);
            const r = ldexp_cexp(v, -1);
            return Complex(f64).init(r.re * math.copysign(@as(f64, 1.0), x), r.im);
        }
        // x >= 1455: result always overflows
        else {
            const h = 0x1p1023 * x;
            return Complex(f64).init(h * @cos(y), h * h * @sin(y));
        }
    }

    if (ix | lx == 0 and iy >= 0x7ff00000) {
        return Complex(f64).init(math.copysign(@as(f64, 0.0), x * (y - y)), y - y);
    }

    if (iy | ly == 0 and ix >= 0x7ff00000) {
        if ((hx & 0xfffff) | lx == 0) {
            return Complex(f64).init(x, y);
        }
        return Complex(f64).init(x, math.copysign(@as(f64, 0.0), y));
    }

    if (ix < 0x7ff00000 and iy >= 0x7ff00000) {
        return Complex(f64).init(y - y, x * (y - y));
    }

    if (ix >= 0x7ff00000 and (hx & 0xfffff) | lx == 0) {
        if (iy >= 0x7ff00000) {
            return Complex(f64).init(x * x, x * (y - y));
        }
        return Complex(f64).init(x * @cos(y), math.inf(f64) * @sin(y));
    }

    return Complex(f64).init((x * x) * (y - y), (x + x) * (y - y));
}

const epsilon = 0.0001;

test "complex.csinh32" {
    const a = Complex(f32).init(5, 3);
    const c = sinh(a);

    try testing.expect(math.approxEqAbs(f32, c.re, -73.460617, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 10.472508, epsilon));
}

test "complex.csinh64" {
    const a = Complex(f64).init(5, 3);
    const c = sinh(a);

    try testing.expect(math.approxEqAbs(f64, c.re, -73.460617, epsilon));
    try testing.expect(math.approxEqAbs(f64, c.im, 10.472508, epsilon));
}

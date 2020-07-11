// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csinhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csinh.c

const builtin = @import("builtin");
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
            return Complex(f32).new(math.sinh(x), y);
        }
        // small x: normal case
        if (ix < 0x41100000) {
            return Complex(f32).new(math.sinh(x) * math.cos(y), math.cosh(x) * math.sin(y));
        }

        // |x|>= 9, so cosh(x) ~= exp(|x|)
        if (ix < 0x42b17218) {
            // x < 88.7: exp(|x|) won't overflow
            const h = math.exp(math.fabs(x)) * 0.5;
            return Complex(f32).new(math.copysign(f32, h, x) * math.cos(y), h * math.sin(y));
        }
        // x < 192.7: scale to avoid overflow
        else if (ix < 0x4340b1e7) {
            const v = Complex(f32).new(math.fabs(x), y);
            const r = ldexp_cexp(v, -1);
            return Complex(f32).new(r.re * math.copysign(f32, 1, x), r.im);
        }
        // x >= 192.7: result always overflows
        else {
            const h = 0x1p127 * x;
            return Complex(f32).new(h * math.cos(y), h * h * math.sin(y));
        }
    }

    if (ix == 0 and iy >= 0x7f800000) {
        return Complex(f32).new(math.copysign(f32, 0, x * (y - y)), y - y);
    }

    if (iy == 0 and ix >= 0x7f800000) {
        if (hx & 0x7fffff == 0) {
            return Complex(f32).new(x, y);
        }
        return Complex(f32).new(x, math.copysign(f32, 0, y));
    }

    if (ix < 0x7f800000 and iy >= 0x7f800000) {
        return Complex(f32).new(y - y, x * (y - y));
    }

    if (ix >= 0x7f800000 and (hx & 0x7fffff) == 0) {
        if (iy >= 0x7f800000) {
            return Complex(f32).new(x * x, x * (y - y));
        }
        return Complex(f32).new(x * math.cos(y), math.inf_f32 * math.sin(y));
    }

    return Complex(f32).new((x * x) * (y - y), (x + x) * (y - y));
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
            return Complex(f64).new(math.sinh(x), y);
        }
        // small x: normal case
        if (ix < 0x40360000) {
            return Complex(f64).new(math.sinh(x) * math.cos(y), math.cosh(x) * math.sin(y));
        }

        // |x|>= 22, so cosh(x) ~= exp(|x|)
        if (ix < 0x40862e42) {
            // x < 710: exp(|x|) won't overflow
            const h = math.exp(math.fabs(x)) * 0.5;
            return Complex(f64).new(math.copysign(f64, h, x) * math.cos(y), h * math.sin(y));
        }
        // x < 1455: scale to avoid overflow
        else if (ix < 0x4096bbaa) {
            const v = Complex(f64).new(math.fabs(x), y);
            const r = ldexp_cexp(v, -1);
            return Complex(f64).new(r.re * math.copysign(f64, 1, x), r.im);
        }
        // x >= 1455: result always overflows
        else {
            const h = 0x1p1023 * x;
            return Complex(f64).new(h * math.cos(y), h * h * math.sin(y));
        }
    }

    if (ix | lx == 0 and iy >= 0x7ff00000) {
        return Complex(f64).new(math.copysign(f64, 0, x * (y - y)), y - y);
    }

    if (iy | ly == 0 and ix >= 0x7ff00000) {
        if ((hx & 0xfffff) | lx == 0) {
            return Complex(f64).new(x, y);
        }
        return Complex(f64).new(x, math.copysign(f64, 0, y));
    }

    if (ix < 0x7ff00000 and iy >= 0x7ff00000) {
        return Complex(f64).new(y - y, x * (y - y));
    }

    if (ix >= 0x7ff00000 and (hx & 0xfffff) | lx == 0) {
        if (iy >= 0x7ff00000) {
            return Complex(f64).new(x * x, x * (y - y));
        }
        return Complex(f64).new(x * math.cos(y), math.inf_f64 * math.sin(y));
    }

    return Complex(f64).new((x * x) * (y - y), (x + x) * (y - y));
}

const epsilon = 0.0001;

test "complex.csinh32" {
    const a = Complex(f32).new(5, 3);
    const c = sinh(a);

    testing.expect(math.approxEq(f32, c.re, -73.460617, epsilon));
    testing.expect(math.approxEq(f32, c.im, 10.472508, epsilon));
}

test "complex.csinh64" {
    const a = Complex(f64).new(5, 3);
    const c = sinh(a);

    testing.expect(math.approxEq(f64, c.re, -73.460617, epsilon));
    testing.expect(math.approxEq(f64, c.im, 10.472508, epsilon));
}

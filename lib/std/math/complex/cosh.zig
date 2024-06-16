// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ccoshf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ccosh.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

const ldexp_cexp = @import("ldexp.zig").ldexp_cexp;

/// Returns the hyperbolic arc-cosine of z.
pub fn cosh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    return switch (T) {
        f32 => cosh32(z),
        f64 => cosh64(z),
        else => @compileError("cosh not implemented for " ++ @typeName(z)),
    };
}

fn cosh32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const hx: u32 = @bitCast(x);
    const ix = hx & 0x7fffffff;

    const hy: u32 = @bitCast(y);
    const iy = hy & 0x7fffffff;

    if (ix < 0x7f800000 and iy < 0x7f800000) return ret: {
        if (iy == 0) break :ret .{
            .re = math.cosh(x),
            .im = y,
        };

        // small x: normal case
        if (ix < 0x41100000) break :ret .{
            .re = math.cosh(x) * @cos(y),
            .im = math.sinh(x) * @sin(y),
        };

        // |x|>= 9, so cosh(x) ~= exp(|x|)
        if (ix < 0x42b17218) {
            // x < 88.7: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;
            break :ret .{
                .re = @cos(y) * math.copysign(h, x),
                .im = @sin(y) * h,
            };
        }

        // x < 192.7: scale to avoid overflow
        if (ix < 0x4340b1e7) {
            const r = ldexp_cexp(Complex(f32).init(@abs(x), y), -1);
            break :ret .{
                .re = r.re,
                .im = r.im * math.copysign(@as(f32, 1.0), x),
            };
        }

        // x >= 192.7: result always overflows
        const h = 0x1p127 * x;
        break :ret .{
            .re = @cos(y) * h * h,
            .im = @sin(y) * h,
        };
    };

    if (ix == 0 and iy >= 0x7f800000) return .{
        .re = y - y,
        .im = math.copysign(@as(f32, 0.0), x * (y - y)),
    };

    if (iy == 0 and ix >= 0x7f800000) {
        return if (hx & 0x7fffff == 0) .{
            .re = x * x,
            .im = y * math.copysign(@as(f32, 0.0), x),
        } else .{
            .re = x,
            .im = math.copysign(@as(f32, 0.0), (x + x) * y),
        };
    }

    if (ix < 0x7f800000 and iy >= 0x7f800000) return .{
        .re = y - y,
        .im = x * (y - y),
    };

    if (ix >= 0x7f800000 and (hx & 0x7fffff) == 0) {
        return if (iy >= 0x7f800000) .{
            .re = x * x,
            .im = x * (y - y),
        } else .{
            .re = @cos(y) * (x * x),
            .im = @sin(y) * x,
        };
    }

    return .{
        .re = (x * x) * (y - y),
        .im = (x + x) * (y - y),
    };
}

fn cosh64(z: Complex(f64)) Complex(f64) {
    const x = z.re;
    const y = z.im;

    const fx: u64 = @bitCast(x);
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);
    const ix = hx & 0x7fffffff;

    const fy: u64 = @bitCast(y);
    const hy: u32 = @intCast(fy >> 32);
    const ly: u32 = @truncate(fy);
    const iy = hy & 0x7fffffff;

    // nearly non-exceptional case where x, y are finite
    if (ix < 0x7ff00000 and iy < 0x7ff00000) return ret: {
        if (iy | ly == 0) break :ret .{
            .re = math.cosh(x),
            .im = x * y,
        };

        // small x: normal case
        if (ix < 0x40360000) break :ret .{
            .re = math.cosh(x) * @cos(y),
            .im = math.sinh(x) * @sin(y),
        };

        // |x|>= 22, so cosh(x) ~= exp(|x|)
        if (ix < 0x40862e42) {
            // x < 710: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;
            break :ret .{
                .re = @cos(y) * h,
                .im = @sin(y) * math.copysign(h, x),
            };
        }

        // x < 1455: scale to avoid overflow
        if (ix < 0x4096bbaa) {
            const r = ldexp_cexp(Complex(f64).init(@abs(x), y), -1);
            break :ret .{
                .re = r.re,
                .im = r.im * math.copysign(@as(f64, 1.0), x),
            };
        }

        // x >= 1455: result always overflows
        const h = 0x1p1023;
        break :ret .{
            .re = @cos(y) * h * h,
            .im = @sin(y) * h,
        };
    };

    if (ix | lx == 0 and iy >= 0x7ff00000) return .{
        .re = y - y,
        .im = math.copysign(@as(f64, 0.0), x * (y - y)),
    };

    if (iy | ly == 0 and ix >= 0x7ff00000) {
        return if ((hx & 0xfffff) | lx == 0) .{
            .re = x * x,
            .im = y * math.copysign(@as(f64, 0.0), x),
        } else .{
            .re = x * x,
            .im = math.copysign(@as(f64, 0.0), (x + x) * y),
        };
    }

    if (ix < 0x7ff00000 and iy >= 0x7ff00000) return .{
        .re = y - y,
        .im = x * (y - y),
    };

    if (ix >= 0x7ff00000 and (hx & 0xfffff) | lx == 0) {
        return if (iy >= 0x7ff00000) .{
            .re = x * x,
            .im = x * (y - y),
        } else .{
            .re = @cos(y) * x * x,
            .im = @sin(y) * x,
        };
    }

    return .{
        .re = (x * x) * (y - y),
        .im = (x + x) * (y - y),
    };
}

const epsilon = 0.0001;

test cosh32 {
    const a = Complex(f32).init(5, 3);
    const c = cosh(a);

    try testing.expect(math.approxEqAbs(f32, c.re, -73.467300, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 10.471557, epsilon));
}

test cosh64 {
    const a = Complex(f64).init(5, 3);
    const c = cosh(a);

    try testing.expect(math.approxEqAbs(f64, c.re, -73.467300, epsilon));
    try testing.expect(math.approxEqAbs(f64, c.im, 10.471557, epsilon));
}

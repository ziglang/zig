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
pub fn sinh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    return switch (T) {
        f32 => sinh32(z),
        f64 => sinh64(z),
        else => @compileError("tan not implemented for " ++ @typeName(z)),
    };
}

fn sinh32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const hx: u32 = @bitCast(x);
    const ix = hx & 0x7fffffff;

    const hy: u32 = @bitCast(y);
    const iy = hy & 0x7fffffff;

    if (ix < 0x7f800000 and iy < 0x7f800000) return ret: {
        if (iy == 0) break :ret .{
            .re = math.sinh(x),
            .im = y,
        };

        // small x: normal case
        if (ix < 0x41100000) break :ret .{
            .re = math.sinh(x) * @cos(y),
            .im = math.cosh(x) * @sin(y),
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
                .re = r.re * math.copysign(@as(f32, 1.0), x),
                .im = r.im,
            };
        }

        // x >= 192.7: result always overflows
        const h = 0x1p127 * x;
        break :ret .{
            .re = @cos(y) * h,
            .im = @sin(y) * h * h,
        };
    };

    if (ix == 0 and iy >= 0x7f800000) return .{
        .re = math.copysign(@as(f32, 0.0), x * (y - y)),
        .im = y - y,
    };

    if (iy == 0 and ix >= 0x7f800000) return .{
        .re = x,
        .im = if (hx & 0x7fffff == 0) y else math.copysign(@as(f32, 0.0), y),
    };

    if (ix < 0x7f800000 and iy >= 0x7f800000) return .{
        .re = y - y,
        .im = x * (y - y),
    };

    if (ix >= 0x7f800000 and (hx & 0x7fffff) == 0) {
        return if (iy >= 0x7f800000) .{
            .re = x * x,
            .im = x * (y - y),
        } else .{
            .re = @cos(y) * x,
            .im = @sin(y) * math.inf(f32),
        };
    }

    return .{
        .re = (x * x) * (y - y),
        .im = (x + x) * (y - y),
    };
}

fn sinh64(z: Complex(f64)) Complex(f64) {
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

    if (ix < 0x7ff00000 and iy < 0x7ff00000) return ret: {
        if (iy | ly == 0) break :ret .{
            .re = math.sinh(x),
            .im = y,
        };

        // small x: normal case
        if (ix < 0x40360000) break :ret .{
            .re = math.sinh(x) * @cos(y),
            .im = math.cosh(x) * @sin(y),
        };

        // |x|>= 22, so cosh(x) ~= exp(|x|)
        if (ix < 0x40862e42) {
            // x < 710: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;
            break :ret .{
                .re = @cos(y) * math.copysign(h, x),
                .im = @sin(y) * h,
            };
        }

        // x < 1455: scale to avoid overflow
        if (ix < 0x4096bbaa) {
            const r = ldexp_cexp(Complex(f64).init(@abs(x), y), -1);
            break :ret .{
                .re = r.re * math.copysign(@as(f64, 1.0), x),
                .im = r.im,
            };
        }

        // x >= 1455: result always overflows
        const h = 0x1p1023 * x;
        break :ret .{
            .re = @cos(y) * h,
            .im = @sin(y) * h * h,
        };
    };

    if (ix | lx == 0 and iy >= 0x7ff00000) return .{
        .re = math.copysign(@as(f64, 0.0), x * (y - y)),
        .im = y - y,
    };

    if (iy | ly == 0 and ix >= 0x7ff00000) return .{
        .re = x,
        .im = if ((hx & 0xfffff) | lx == 0) y else math.copysign(@as(f64, 0.0), y),
    };

    if (ix < 0x7ff00000 and iy >= 0x7ff00000) return .{
        .re = y - y,
        .im = x * (y - y),
    };

    if (ix >= 0x7ff00000 and (hx & 0xfffff) | lx == 0) {
        return if (iy >= 0x7ff00000) .{
            .re = x * x,
            .im = x * (y - y),
        } else .{
            .re = @cos(y) * x,
            .im = @sin(y) * math.inf(f64),
        };
    }

    return .{
        .re = (x * x) * (y - y),
        .im = (x + x) * (y - y),
    };
}

const epsilon = 0.0001;

test sinh32 {
    const a = Complex(f32).init(5, 3);
    const c = sinh(a);

    try testing.expect(math.approxEqAbs(f32, c.re, -73.460617, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 10.472508, epsilon));
}

test sinh64 {
    const a = Complex(f64).init(5, 3);
    const c = sinh(a);

    try testing.expect(math.approxEqAbs(f64, c.re, -73.460617, epsilon));
    try testing.expect(math.approxEqAbs(f64, c.im, 10.472508, epsilon));
}

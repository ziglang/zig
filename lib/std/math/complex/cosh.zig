// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ccoshf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ccosh.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;

const ldexp_cexp32 = @import("ldexp.zig").ldexp_cexp32;
const ldexp_cexp64 = @import("ldexp.zig").ldexp_cexp64;

pub fn cosh32(x: f32, y: f32) [2]f32 {
    const hx: u32 = @bitCast(x);
    const ix = hx & 0x7fffffff;

    const hy: u32 = @bitCast(y);
    const iy = hy & 0x7fffffff;

    if (ix < 0x7f800000 and iy < 0x7f800000) return ret: {
        if (iy == 0) break :ret .{ math.cosh(x), y };

        // small x: normal case
        if (ix < 0x41100000) break :ret .{
            math.cosh(x) * @cos(y),
            math.sinh(x) * @sin(y),
        };

        // |x|>= 9, so cosh(x) ~= exp(|x|)
        if (ix < 0x42b17218) {
            // x < 88.7: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;
            break :ret .{
                @cos(y) * math.copysign(h, x),
                @sin(y) * h,
            };
        }

        // x < 192.7: scale to avoid overflow
        if (ix < 0x4340b1e7) {
            const r = ldexp_cexp32(@abs(x), y, -1);
            break :ret .{
                r[0],
                r[1] * math.copysign(@as(f32, 1.0), x),
            };
        }

        // x >= 192.7: result always overflows
        const h = 0x1p127 * x;
        break :ret .{
            @cos(y) * h * h,
            @sin(y) * h,
        };
    };

    if (ix == 0 and iy >= 0x7f800000) return .{
        y - y,
        math.copysign(@as(f32, 0.0), x * (y - y)),
    };

    if (iy == 0 and ix >= 0x7f800000) {
        return if (hx & 0x7fffff == 0) .{
            x * x,
            y * math.copysign(@as(f32, 0.0), x),
        } else .{
            x,
            math.copysign(@as(f32, 0.0), (x + x) * y),
        };
    }

    if (ix < 0x7f800000 and iy >= 0x7f800000) return .{
        y - y,
        x * (y - y),
    };

    if (ix >= 0x7f800000 and (hx & 0x7fffff) == 0) {
        return if (iy >= 0x7f800000) .{
            x * x,
            x * (y - y),
        } else .{
            @cos(y) * x * x,
            @sin(y) * x,
        };
    }

    return .{
        (x * x) * (y - y),
        (x + x) * (y - y),
    };
}

pub fn cosh64(x: f64, y: f64) [2]f64 {
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
            math.cosh(x),
            x * y,
        };

        // small x: normal case
        if (ix < 0x40360000) break :ret .{
            math.cosh(x) * @cos(y),
            math.sinh(x) * @sin(y),
        };

        // |x|>= 22, so cosh(x) ~= exp(|x|)
        if (ix < 0x40862e42) {
            // x < 710: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;
            break :ret .{
                @cos(y) * h,
                @sin(y) * math.copysign(h, x),
            };
        }

        // x < 1455: scale to avoid overflow
        if (ix < 0x4096bbaa) {
            const r = ldexp_cexp64(@abs(x), y, -1);
            break :ret .{
                r[0],
                r[1] * math.copysign(@as(f64, 1.0), x),
            };
        }

        // x >= 1455: result always overflows
        const h = 0x1p1023;
        break :ret .{
            @cos(y) * h * h,
            @sin(y) * h,
        };
    };

    if (ix | lx == 0 and iy >= 0x7ff00000) return .{
        y - y,
        math.copysign(@as(f64, 0.0), x * (y - y)),
    };

    if (iy | ly == 0 and ix >= 0x7ff00000) {
        return if ((hx & 0xfffff) | lx == 0) .{
            x * x,
            y * math.copysign(@as(f64, 0.0), x),
        } else .{
            x * x,
            math.copysign(@as(f64, 0.0), (x + x) * y),
        };
    }

    if (ix < 0x7ff00000 and iy >= 0x7ff00000) return .{
        y - y,
        x * (y - y),
    };

    if (ix >= 0x7ff00000 and (hx & 0xfffff) | lx == 0) {
        return if (iy >= 0x7ff00000) .{
            x * x,
            x * (y - y),
        } else .{
            @cos(y) * x * x,
            @sin(y) * x,
        };
    }

    return .{
        (x * x) * (y - y),
        (x + x) * (y - y),
    };
}

test cosh32 {
    const z = cosh32(5, 3);
    const re: f32 = -73.46729221264526;
    const im: f32 = 10.471557674805572;
    try testing.expect(math.approxEqAbs(f32, z[0], re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z[1], im, @sqrt(math.floatEpsAt(f32, im))));
}

test cosh64 {
    const z = cosh64(5, 3);
    const re: f64 = -73.46729221264526;
    const im: f64 = 10.471557674805572;
    try testing.expect(math.approxEqAbs(f64, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
    try testing.expect(math.approxEqAbs(f64, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
}

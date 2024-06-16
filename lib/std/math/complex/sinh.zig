// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csinhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csinh.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;

const ldexp_cexp32 = @import("ldexp.zig").ldexp_cexp32;
const ldexp_cexp64 = @import("ldexp.zig").ldexp_cexp64;

pub fn sinh32(x: f32, y: f32) [2]f32 {
    const huge: f32 = 0x1p127;
    const zero: f32 = 0;
    const one: f32 = 1;
    const inf: f32 = math.inf(f32);

    const hx: u32 = @bitCast(x);
    const ix = hx & 0x7fffffff;

    const hy: u32 = @bitCast(y);
    const iy = hy & 0x7fffffff;

    if (ix < 0x7f800000 and iy < 0x7f800000) return ret: {
        if (iy == 0) break :ret .{
            math.sinh(x),
            y,
        };

        // small x: normal case
        if (ix < 0x41100000) break :ret .{
            math.sinh(x) * @cos(y),
            math.cosh(x) * @sin(y),
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
            const z = ldexp_cexp32(@abs(x), y, -1);
            break :ret .{
                z[0] * math.copysign(one, x),
                z[1],
            };
        }

        // x >= 192.7: result always overflows
        const h = huge * x;
        break :ret .{
            @cos(y) * h,
            @sin(y) * (h * h),
        };
    };

    if (ix == 0 and iy >= 0x7f800000) return .{
        math.copysign(zero, (y - y) * x),
        (y - y),
    };

    if (iy == 0 and ix >= 0x7f800000) return .{
        x,
        if (hx & 0x7fffff == 0) y else math.copysign(zero, y),
    };

    if (ix < 0x7f800000 and iy >= 0x7f800000) return .{
        (y - y),
        (y - y) * x,
    };

    if (ix >= 0x7f800000 and (hx & 0x7fffff) == 0) {
        return if (iy >= 0x7f800000) .{
            (x * x),
            (y - y) * x,
        } else .{
            @cos(y) * x,
            @sin(y) * inf,
        };
    }

    return .{
        (x * x) * (y - y),
        (x + x) * (y - y),
    };
}

pub fn sinh64(x: f64, y: f64) [2]f64 {
    const huge: f64 = 0x1p1023;
    const zero: f64 = 0;
    const one: f64 = 1;
    const inf: f64 = math.inf(f64);

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
            math.sinh(x),
            y,
        };

        // small x: normal case
        if (ix < 0x40360000) break :ret .{
            math.sinh(x) * @cos(y),
            math.cosh(x) * @sin(y),
        };

        // |x|>= 22, so cosh(x) ~= exp(|x|)
        if (ix < 0x40862e42) {
            // x < 710: exp(|x|) won't overflow
            const h = @exp(@abs(x)) * 0.5;
            break :ret .{
                @cos(y) * math.copysign(h, x),
                @sin(y) * h,
            };
        }

        // x < 1455: scale to avoid overflow
        if (ix < 0x4096bbaa) {
            const z = ldexp_cexp64(@abs(x), y, -1);
            break :ret .{
                z[0] * math.copysign(one, x),
                z[1],
            };
        }

        // x >= 1455: result always overflows
        const h = huge * x;
        break :ret .{
            @cos(y) * h,
            @sin(y) * (h * h),
        };
    };

    if (ix | lx == 0 and iy >= 0x7ff00000) return .{
        math.copysign(zero, (y - y) * x),
        (y - y),
    };

    if (iy | ly == 0 and ix >= 0x7ff00000) return .{
        x,
        if ((hx & 0xfffff) | lx == 0) y else math.copysign(zero, y),
    };

    if (ix < 0x7ff00000 and iy >= 0x7ff00000) return .{
        (y - y),
        (y - y) * x,
    };

    if (ix >= 0x7ff00000 and (hx & 0xfffff) | lx == 0) {
        return if (iy >= 0x7ff00000) .{
            x * x,
            x * (y - y),
        } else .{
            @cos(y) * x,
            @sin(y) * inf,
        };
    }

    return .{
        (x * x) * (y - y),
        (x + x) * (y - y),
    };
}

test sinh32 {
    const z = sinh32(5, 3);
    const re: f32 = -73.46062169567367;
    const im: f32 = 10.472508533940392;
    try testing.expect(math.approxEqAbs(f32, z[0], re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z[1], im, @sqrt(math.floatEpsAt(f32, im))));
}

test sinh64 {
    const z = sinh64(5, 3);
    const re: f64 = -73.46062169567367;
    const im: f64 = 10.472508533940392;
    try testing.expect(math.approxEqAbs(f64, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
    try testing.expect(math.approxEqAbs(f64, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
}

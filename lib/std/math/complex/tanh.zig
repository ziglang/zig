// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ctanhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/ctanh.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;

const ldexp_cexp32 = @import("ldexp.zig").ldexp_cexp32;
const ldexp_cexp64 = @import("ldexp.zig").ldexp_cexp64;

fn kahan(comptime T: type, x: T, y: T) [2]T {
    // Kahan's algorithm
    const t = @tan(y);
    const beta = 1.0 + t * t;
    const s = math.sinh(x);
    const rho = @sqrt(1 + s * s);
    const den = 1 + beta * s * s;
    return .{
        (beta * rho * s) / den,
        t / den,
    };
}

pub const tanhFallback = kahan;

pub fn tanh32(x: f32, y: f32) [2]f32 {
    const zero: f32 = 0;
    const one: f32 = 1;

    const hx: u32 = @bitCast(x);
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7f800000) {
        return if (ix & 0x7fffff != 0) .{
            x,
            if (y == 0) y else x * y,
        } else .{
            @bitCast(hx - 0x40000000),
            math.copysign(zero, if (math.isInf(y)) y else @sin(y) * @cos(y)),
        };
    }

    if (!math.isFinite(y)) return .{
        if (ix != 0) y - y else x,
        y - y,
    };

    // x >= 11
    if (ix >= 0x41300000) {
        const exp_mx = @exp(-@abs(x));
        return .{
            math.copysign(one, x),
            4 * @sin(y) * @cos(y) * exp_mx * exp_mx,
        };
    }

    return kahan(f32, x, y);
}

pub fn tanh64(x: f64, y: f64) [2]f64 {
    const zero: f64 = 0;
    const one: f64 = 1;

    const fx: u64 = @bitCast(x);
    // TODO: zig should allow this conversion implicitly because it can notice that the value necessarily
    // fits in range.
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);
    const ix = hx & 0x7fffffff;

    if (ix >= 0x7ff00000) {
        return if ((ix & 0x7fffff) | lx != 0) .{
            x,
            if (y == 0) y else x * y,
        } else .{
            @bitCast((@as(u64, hx - 0x40000000) << 32) | lx),
            math.copysign(zero, if (math.isInf(y)) y else @sin(y) * @cos(y)),
        };
    }

    if (!math.isFinite(y)) return .{
        if (ix != 0) y - y else x,
        y - y,
    };

    // x >= 22
    if (ix >= 0x40360000) {
        const exp_mx = @exp(-@abs(x));
        return .{
            math.copysign(one, x),
            4 * @sin(y) * @cos(y) * exp_mx * exp_mx,
        };
    }

    return kahan(f64, x, y);
}

test tanh32 {
    const z = tanh32(5, 3);
    const re: f32 = 0.9999128201513536;
    const im: f32 = -2.536867620767604e-5;
    try testing.expect(math.approxEqAbs(f32, z[0], re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z[1], im, @sqrt(math.floatEpsAt(f32, im))));
}

test tanh64 {
    const z = tanh64(5, 3);
    const re: f64 = 0.9999128201513536;
    const im: f64 = -2.536867620767604e-5;
    try testing.expect(math.approxEqAbs(f64, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
    try testing.expect(math.approxEqAbs(f64, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
}

test tanhFallback {
    const re = 0.9999128201513536;
    const im = -2.536867620767604e-5;
    inline for (.{ f32, f64 }) |F| {
        const z = tanhFallback(F, 5, 3);
        try testing.expect(math.approxEqAbs(F, z[0], re, @sqrt(math.floatEpsAt(F, re))));
        try testing.expect(math.approxEqAbs(F, z[1], im, @sqrt(math.floatEpsAt(F, im))));
    }
    { // separate f128 test with less strict tolerance
        const z = tanhFallback(f128, 5, 3);
        try testing.expect(math.approxEqAbs(f128, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
        try testing.expect(math.approxEqAbs(f128, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
    }
}

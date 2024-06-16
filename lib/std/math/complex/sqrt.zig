// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csqrtf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/csqrt.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;

pub fn sqrt32(x: f32, y: f32) [2]f32 {
    if (x == 0 and y == 0) return .{ 0, y };

    if (math.isInf(y)) return .{ math.inf(f32), y };

    if (math.isNan(x)) return .{
        x,
        (y - y) / (y - y), // raise invalid if y is not nan
    };

    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        return if (math.signbit(x)) .{
            @abs(x - y),
            math.copysign(x, y),
        } else .{
            x,
            math.copysign(y - y, y),
        };
    }

    // y = nan special case is handled fine below

    // double-precision avoids overflow with correct rounding.
    const dx: f64 = x;
    const dy: f64 = y;

    if (dx >= 0) {
        const t = @sqrt(0.5 * (math.hypot(dx, dy) + dx));
        return .{
            @floatCast(t),
            @floatCast(dy / (2.0 * t)),
        };
    } else {
        const t = @sqrt(0.5 * (math.hypot(dx, dy) - dx));
        return .{
            @floatCast(@abs(y) / (2.0 * t)),
            @floatCast(math.copysign(t, y)),
        };
    }
}

pub fn sqrt64(z_re: f64, z_im: f64) [2]f64 {
    // may encounter overflow for im,re >= DBL_MAX / (1 + sqrt(2))
    const threshold = 0x1.a827999fcef32p+1022;

    var x = z_re;
    var y = z_im;

    if (x == 0 and y == 0) return .{ 0, y };

    if (math.isInf(y)) return .{ math.inf(f64), y };

    if (math.isNan(x)) return .{
        x,
        (y - y) / (y - y), // raise invalid if y is not nan
    };

    if (math.isInf(x)) {
        // sqrt(inf + i nan)    = inf + nan i
        // sqrt(inf + iy)       = inf + i0
        // sqrt(-inf + i nan)   = nan +- inf i
        // sqrt(-inf + iy)      = 0 + inf i
        return if (math.signbit(x)) .{
            @abs(x - y),
            math.copysign(x, y),
        } else .{
            x,
            math.copysign(y - y, y),
        };
    }

    // y = nan special case is handled fine below

    // scale to avoid overflow
    var scale = false;
    if (@abs(x) >= threshold or @abs(y) >= threshold) {
        x *= 0.25;
        y *= 0.25;
        scale = true;
    }

    var re: f64 = undefined;
    var im: f64 = undefined;
    if (x >= 0) {
        const t = @sqrt(0.5 * (math.hypot(x, y) + x));
        re = t;
        im = y / (2.0 * t);
    } else {
        const t = @sqrt(0.5 * (math.hypot(x, y) - x));
        re = @abs(y) / (2.0 * t);
        im = math.copysign(t, y);
    }

    if (scale) {
        re *= 2;
        im *= 2;
    }

    return .{ re, im };
}

pub fn sqrtFallback(comptime T: type, x: T, y: T) [2]T {
    if (y == 0) return if (x > 0) .{ @sqrt(x), y } else .{ 0, math.copysign(@sqrt(-x), y) };
    const r = math.hypot(x, y);
    const a = 0.5 * x + 0.5 * r;
    const b = 0.5 * y;
    const c = math.hypot(a, b);
    const d = @sqrt(r);
    return .{ a * d / c, b * d / c };
}

test sqrt32 {
    const z = sqrt32(5, 3);
    const re: f32 = 2.3271175190399496;
    const im: f32 = 0.6445742373246469;
    try testing.expect(math.approxEqAbs(f32, z[0], re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z[1], im, @sqrt(math.floatEpsAt(f32, im))));
}

test sqrt64 {
    const z = sqrt64(5, 3);
    const re: f64 = 2.3271175190399496;
    const im: f64 = 0.6445742373246469;
    try testing.expect(math.approxEqAbs(f64, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
    try testing.expect(math.approxEqAbs(f64, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
}

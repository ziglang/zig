// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/cexpf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/cexp.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;

const ldexp_cexp32 = @import("ldexp.zig").ldexp_cexp32;
const ldexp_cexp64 = @import("ldexp.zig").ldexp_cexp64;

pub fn exp32(x: f32, y: f32) [2]f32 {
    const exp_overflow = 0x42b17218; // max_exp * ln2 ~= 88.72283955
    const cexp_overflow = 0x43400074; // (max_exp - min_denom_exp) * ln2

    const hy = @as(u32, @bitCast(y)) & 0x7fffffff;
    // cexp(x + i0) = exp(x) + i0
    if (hy == 0) return .{ @exp(x), y };

    const hx: u32 = @bitCast(x);
    // cexp(0 + iy) = cos(y) + isin(y)
    if ((hx & 0x7fffffff) == 0) return .{ @cos(y), @sin(y) };

    if (hy >= 0x7f800000) {
        // cexp(finite|nan +- i inf|nan) = nan + i nan
        if ((hx & 0x7fffffff) != 0x7f800000) return .{ y - y, y - y };
        // cexp(-inf +- i inf|nan) = 0 + i0
        if (hx & 0x80000000 != 0) return .{ 0, 0 };
        // cexp(+inf +- i inf|nan) = inf + i nan
        return .{ x, y - y };
    }

    // 88.7 <= x <= 192 so must scale
    if (hx >= exp_overflow and hx <= cexp_overflow) return ldexp_cexp32(x, y, 0);

    // - x < exp_overflow => exp(x) won't overflow (common)
    // - x > cexp_overflow, so exp(x) * s overflows for s > 0
    // - x = +-inf
    // - x = nan
    const exp_x = @exp(x);
    return .{
        exp_x * @cos(y),
        exp_x * @sin(y),
    };
}

pub fn exp64(x: f64, y: f64) [2]f64 {
    const exp_overflow = 0x40862e42; // high bits of max_exp * ln2 ~= 710
    const cexp_overflow = 0x4096b8e4; // (max_exp - min_denorm_exp) * ln2

    const fy: u64 = @bitCast(y);
    const hy: u32 = @intCast((fy >> 32) & 0x7fffffff);
    const ly: u32 = @truncate(fy);

    // cexp(x + i0) = exp(x) + i0
    if (hy | ly == 0) return .{ @exp(x), y };

    const fx: u64 = @bitCast(x);
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);

    // cexp(0 + iy) = cos(y) + isin(y)
    if ((hx & 0x7fffffff) | lx == 0) return .{ @cos(y), @sin(y) };

    if (hy >= 0x7ff00000) {
        // cexp(finite|nan +- i inf|nan) = nan + i nan
        if (lx != 0 or (hx & 0x7fffffff) != 0x7ff00000) return .{ y - y, y - y };
        // cexp(-inf +- i inf|nan) = 0 + i0
        if (hx & 0x80000000 != 0) return .{ 0, 0 };
        // cexp(+inf +- i inf|nan) = inf + i nan
        return .{ x, y - y };
    }

    // 709.7 <= x <= 1454.3 so must scale
    if (hx >= exp_overflow and hx <= cexp_overflow) return ldexp_cexp64(x, y, 0);

    // - x < exp_overflow => exp(x) won't overflow (common)
    // - x > cexp_overflow, so exp(x) * s overflows for s > 0
    // - x = +-inf
    // - x = nan
    const exp_x = @exp(x);
    return .{
        exp_x * @cos(y),
        exp_x * @sin(y),
    };
}

pub fn expFallback(comptime T: type, x: T, y: T) [2]T {
    const nan = math.nan(T);
    const inf = math.inf(T);
    if (y == 0) return .{ @exp(x), y }; //           exp(x +- 0i) = exp(x) +- 0i
    if (x == 0) return .{ @cos(y), @sin(y) }; //     exp(0 +  iy) = cos(y) + isin(y)
    if (!math.isFinite(y)) {
        if (!math.isInf(x)) return .{ nan, nan }; // exp(!inf +- i!fin) = nan + i nan
        if (x < 0) return .{ 0, 0 }; //              exp(-inf +- i!fin) = 0 + i0
        return .{ inf, nan }; //                     exp(+inf +- i!fin) = inf + i nan
    }
    const exp_x = @exp(x);
    return .{
        exp_x * @cos(y),
        exp_x * @sin(y),
    };
}

test exp32 {
    {
        const z = exp32(5, 3);
        const re: f32 = -146.92791390831894;
        const im: f32 = 20.944066208745966;
        try testing.expect(math.approxEqAbs(f32, z[0], re, @sqrt(math.floatEpsAt(f32, re))));
        try testing.expect(math.approxEqAbs(f32, z[1], im, @sqrt(math.floatEpsAt(f32, im))));
    }
    {
        const z = exp32(88.8, 0x1p-149);
        const re: f32 = math.inf(f32);
        const im: f32 = 5.15088629e-07;
        try testing.expect(math.approxEqAbs(f32, z[0], re, @sqrt(math.floatEps(f32))));
        try testing.expect(math.approxEqAbs(f32, z[1], im, @sqrt(math.floatEps(f32))));
    }
}

test exp64 {
    {
        const z = exp64(5, 3);
        const re: f64 = -146.92791390831894;
        const im: f64 = 20.944066208745966;
        try testing.expect(math.approxEqAbs(f64, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
        try testing.expect(math.approxEqAbs(f64, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
    }
    {
        const z = exp64(709.8, 0x1p-1074);
        const re: f64 = math.inf(f64);
        const im: f64 = 9.036659362159884e-16;
        try testing.expectApproxEqAbs(re, z[0], @sqrt(math.floatEps(f64)));
        try testing.expectApproxEqAbs(im, z[1], @sqrt(math.floatEps(f64)));
    }
}

test expFallback {
    const re = -146.92791390831894;
    const im = 20.944066208745966;
    inline for (.{ f16, f32, f64 }) |F| {
        const z = expFallback(F, 5, 3);
        try testing.expect(math.approxEqAbs(F, z[0], re, @sqrt(math.floatEpsAt(F, re))));
        try testing.expect(math.approxEqAbs(F, z[1], im, @sqrt(math.floatEpsAt(F, im))));
    }
    { // separate f128 test with less strict tolerance
        const z = expFallback(f128, 5, 3);
        try testing.expect(math.approxEqAbs(f128, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
        try testing.expect(math.approxEqAbs(f128, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
    }
}

// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/log1pf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/log1p.c

const std = @import("../std.zig");
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Returns the natural logarithm of 1 + x with greater accuracy when x is near zero.
///
/// Special Cases:
///  - log1p(+inf)  = +inf
///  - log1p(+-0)   = +-0
///  - log1p(-1)    = -inf
///  - log1p(x)     = nan if x < -1
///  - log1p(nan)   = nan
pub fn log1p(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => log1p_32(x),
        f64 => log1p_64(x),
        else => @compileError("log1p not implemented for " ++ @typeName(T)),
    };
}

fn log1p_32(x: f32) f32 {
    const ln2_hi = 6.9313812256e-01;
    const ln2_lo = 9.0580006145e-06;
    const Lg1: f32 = 0xaaaaaa.0p-24;
    const Lg2: f32 = 0xccce13.0p-25;
    const Lg3: f32 = 0x91e9ee.0p-25;
    const Lg4: f32 = 0xf89e26.0p-26;

    const u: u32 = @bitCast(x);
    const ix = u;
    var k: i32 = 1;
    var f: f32 = undefined;
    var c: f32 = undefined;

    // 1 + x < sqrt(2)+
    if (ix < 0x3ED413D0 or ix >> 31 != 0) {
        // x <= -1.0
        if (ix >= 0xBF800000) {
            // log1p(-1) = -inf
            if (x == -1.0) {
                return -math.inf(f32);
            }
            // log1p(x < -1) = nan
            else {
                return math.nan(f32);
            }
        }
        // |x| < 2^(-24)
        if ((ix << 1) < (0x33800000 << 1)) {
            // underflow if subnormal
            if (ix & 0x7F800000 == 0) {
                mem.doNotOptimizeAway(x * x);
            }
            return x;
        }
        // sqrt(2) / 2- <= 1 + x < sqrt(2)+
        if (ix <= 0xBE95F619) {
            k = 0;
            c = 0;
            f = x;
        }
    } else if (ix >= 0x7F800000) {
        return x;
    }

    if (k != 0) {
        const uf = 1 + x;
        var iu = @as(u32, @bitCast(uf));
        iu += 0x3F800000 - 0x3F3504F3;
        k = @as(i32, @intCast(iu >> 23)) - 0x7F;

        // correction to avoid underflow in c / u
        if (k < 25) {
            c = if (k >= 2) 1 - (uf - x) else x - (uf - 1);
            c /= uf;
        } else {
            c = 0;
        }

        // u into [sqrt(2)/2, sqrt(2)]
        iu = (iu & 0x007FFFFF) + 0x3F3504F3;
        f = @as(f32, @bitCast(iu)) - 1;
    }

    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * Lg4);
    const t2 = z * (Lg1 + w * Lg3);
    const R = t2 + t1;
    const hfsq = 0.5 * f * f;
    const dk = @as(f32, @floatFromInt(k));

    return s * (hfsq + R) + (dk * ln2_lo + c) - hfsq + f + dk * ln2_hi;
}

fn log1p_64(x: f64) f64 {
    const ln2_hi: f64 = 6.93147180369123816490e-01;
    const ln2_lo: f64 = 1.90821492927058770002e-10;
    const Lg1: f64 = 6.666666666666735130e-01;
    const Lg2: f64 = 3.999999999940941908e-01;
    const Lg3: f64 = 2.857142874366239149e-01;
    const Lg4: f64 = 2.222219843214978396e-01;
    const Lg5: f64 = 1.818357216161805012e-01;
    const Lg6: f64 = 1.531383769920937332e-01;
    const Lg7: f64 = 1.479819860511658591e-01;

    const ix: u64 = @bitCast(x);
    const hx: u32 = @intCast(ix >> 32);
    var k: i32 = 1;
    var c: f64 = undefined;
    var f: f64 = undefined;

    // 1 + x < sqrt(2)
    if (hx < 0x3FDA827A or hx >> 31 != 0) {
        // x <= -1.0
        if (hx >= 0xBFF00000) {
            // log1p(-1) = -inf
            if (x == -1.0) {
                return -math.inf(f64);
            }
            // log1p(x < -1) = nan
            else {
                return math.nan(f64);
            }
        }
        // |x| < 2^(-53)
        if ((hx << 1) < (0x3CA00000 << 1)) {
            if ((hx & 0x7FF00000) == 0) {
                math.raiseUnderflow();
            }
            return x;
        }
        // sqrt(2) / 2- <= 1 + x < sqrt(2)+
        if (hx <= 0xBFD2BEC4) {
            k = 0;
            c = 0;
            f = x;
        }
    } else if (hx >= 0x7FF00000) {
        return x;
    }

    if (k != 0) {
        const uf = 1 + x;
        const hu = @as(u64, @bitCast(uf));
        var iu = @as(u32, @intCast(hu >> 32));
        iu += 0x3FF00000 - 0x3FE6A09E;
        k = @as(i32, @intCast(iu >> 20)) - 0x3FF;

        // correction to avoid underflow in c / u
        if (k < 54) {
            c = if (k >= 2) 1 - (uf - x) else x - (uf - 1);
            c /= uf;
        } else {
            c = 0;
        }

        // u into [sqrt(2)/2, sqrt(2)]
        iu = (iu & 0x000FFFFF) + 0x3FE6A09E;
        const iq = (@as(u64, iu) << 32) | (hu & 0xFFFFFFFF);
        f = @as(f64, @bitCast(iq)) - 1;
    }

    const hfsq = 0.5 * f * f;
    const s = f / (2.0 + f);
    const z = s * s;
    const w = z * z;
    const t1 = w * (Lg2 + w * (Lg4 + w * Lg6));
    const t2 = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7)));
    const R = t2 + t1;
    const dk = @as(f64, @floatFromInt(k));

    return s * (hfsq + R) + (dk * ln2_lo + c) - hfsq + f + dk * ln2_hi;
}

test "log1p_32() special" {
    try expect(math.isPositiveZero(log1p_32(0.0)));
    try expect(math.isNegativeZero(log1p_32(-0.0)));
    try expectEqual(log1p_32(-1.0), -math.inf(f32));
    try expectEqual(log1p_32(1.0), math.ln2);
    try expectEqual(log1p_32(math.inf(f32)), math.inf(f32));
    try expect(math.isNan(log1p_32(-2.0)));
    try expect(math.isNan(log1p_32(-math.inf(f32))));
    try expect(math.isNan(log1p_32(math.nan(f32))));
    try expect(math.isNan(log1p_32(math.snan(f32))));
}

test "log1p_32() sanity" {
    try expect(math.isNan(log1p_32(-0x1.0223a0p+3)));
    try expectEqual(log1p_32(0x1.161868p+2), 0x1.ad1bdcp+0);
    try expect(math.isNan(log1p_32(-0x1.0c34b4p+3)));
    try expect(math.isNan(log1p_32(-0x1.a206f0p+2)));
    try expectEqual(log1p_32(0x1.288bbcp+3), 0x1.2a1ab8p+1);
    try expectEqual(log1p_32(0x1.52efd0p-1), 0x1.041a4ep-1);
    try expectEqual(log1p_32(-0x1.a05cc8p-2), -0x1.0b3596p-1);
    try expectEqual(log1p_32(0x1.1f9efap-1), 0x1.c88344p-2);
    try expectEqual(log1p_32(0x1.8c5db0p-1), 0x1.258a8ep-1);
    try expectEqual(log1p_32(-0x1.5b86eap-1), -0x1.22b542p+0);
}

test "log1p_32() boundary" {
    try expectEqual(log1p_32(0x1.fffffep+127), 0x1.62e430p+6); // Max input value
    try expectEqual(log1p_32(0x1p-149), 0x1p-149); // Min positive input value
    try expectEqual(log1p_32(-0x1p-149), -0x1p-149); // Min negative input value
    try expectEqual(log1p_32(0x1p-126), 0x1p-126); // First subnormal
    try expectEqual(log1p_32(-0x1p-126), -0x1p-126); // First negative subnormal
    try expectEqual(log1p_32(-0x1.fffffep-1), -0x1.0a2b24p+4); // Last value before result is -inf
    try expect(math.isNan(log1p_32(-0x1.000002p+0))); // First value where result is nan
}

test "log1p_64() special" {
    try expect(math.isPositiveZero(log1p_64(0.0)));
    try expect(math.isNegativeZero(log1p_64(-0.0)));
    try expectEqual(log1p_64(-1.0), -math.inf(f64));
    try expectEqual(log1p_64(1.0), math.ln2);
    try expectEqual(log1p_64(math.inf(f64)), math.inf(f64));
    try expect(math.isNan(log1p_64(-2.0)));
    try expect(math.isNan(log1p_64(-math.inf(f64))));
    try expect(math.isNan(log1p_64(math.nan(f64))));
    try expect(math.isNan(log1p_64(math.snan(f64))));
}

test "log1p_64() sanity" {
    try expect(math.isNan(log1p_64(-0x1.02239f3c6a8f1p+3)));
    try expectEqual(log1p_64(0x1.161868e18bc67p+2), 0x1.ad1bdd1e9e686p+0); // Disagrees with GCC in last bit
    try expect(math.isNan(log1p_64(-0x1.0c34b3e01e6e7p+3)));
    try expect(math.isNan(log1p_64(-0x1.a206f0a19dcc4p+2)));
    try expectEqual(log1p_64(0x1.288bbb0d6a1e6p+3), 0x1.2a1ab8365b56fp+1);
    try expectEqual(log1p_64(0x1.52efd0cd80497p-1), 0x1.041a4ec2a680ap-1);
    try expectEqual(log1p_64(-0x1.a05cc754481d1p-2), -0x1.0b3595423aec1p-1);
    try expectEqual(log1p_64(0x1.1f9ef934745cbp-1), 0x1.c8834348a846ep-2);
    try expectEqual(log1p_64(0x1.8c5db097f7442p-1), 0x1.258a8e8a35bbfp-1);
    try expectEqual(log1p_64(-0x1.5b86ea8118a0ep-1), -0x1.22b5426327502p+0);
}

test "log1p_64() boundary" {
    try expectEqual(log1p_64(0x1.fffffffffffffp+1023), 0x1.62e42fefa39efp+9); // Max input value
    try expectEqual(log1p_64(0x1p-1074), 0x1p-1074); // Min positive input value
    try expectEqual(log1p_64(-0x1p-1074), -0x1p-1074); // Min negative input value
    try expectEqual(log1p_64(0x1p-1022), 0x1p-1022); // First subnormal
    try expectEqual(log1p_64(-0x1p-1022), -0x1p-1022); // First negative subnormal
    try expectEqual(log1p_64(-0x1.fffffffffffffp-1), -0x1.25e4f7b2737fap+5); // Last value before result is -inf
    try expect(math.isNan(log1p_64(-0x1.0000000000001p+0))); // First value where result is nan
}

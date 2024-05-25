// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/expmf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/expm.c

// TODO: Updated recently.

const std = @import("../std.zig");
const math = std.math;
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Returns e raised to the power of x, minus 1 (e^x - 1). This is more accurate than exp(e, x) - 1
/// when x is near 0.
///
/// Special Cases:
///  - expm1(+inf) = +inf
///  - expm1(-inf) = -1
///  - expm1(nan)  = nan
pub fn expm1(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => expm1_32(x),
        f64 => expm1_64(x),
        else => @compileError("exp1m not implemented for " ++ @typeName(T)),
    };
}

fn expm1_32(x_: f32) f32 {
    if (math.isNan(x_))
        return math.nan(f32);

    const o_threshold: f32 = 8.8721679688e+01;
    const ln2_hi: f32 = 6.9313812256e-01;
    const ln2_lo: f32 = 9.0580006145e-06;
    const invln2: f32 = 1.4426950216e+00;
    const Q1: f32 = -3.3333212137e-2;
    const Q2: f32 = 1.5807170421e-3;

    var x = x_;
    const ux: u32 = @bitCast(x);
    const hx = ux & 0x7FFFFFFF;
    const sign = ux >> 31;

    // TODO: Shouldn't need this check explicitly.
    if (math.isNegativeInf(x)) {
        return -1.0;
    }

    // |x| >= 27 * ln2
    if (hx >= 0x4195B844) {
        // nan
        if (hx > 0x7F800000) {
            return x;
        }
        if (sign != 0) {
            return -1;
        }
        if (x > o_threshold) {
            x *= 0x1.0p127;
            return x;
        }
    }

    var hi: f32 = undefined;
    var lo: f32 = undefined;
    var c: f32 = undefined;
    var k: i32 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3EB17218) {
        // |x| < 1.5 * ln2
        if (hx < 0x3F851592) {
            if (sign == 0) {
                hi = x - ln2_hi;
                lo = ln2_lo;
                k = 1;
            } else {
                hi = x + ln2_hi;
                lo = -ln2_lo;
                k = -1;
            }
        } else {
            var kf = invln2 * x;
            if (sign != 0) {
                kf -= 0.5;
            } else {
                kf += 0.5;
            }

            k = @as(i32, @intFromFloat(kf));
            const t = @as(f32, @floatFromInt(k));
            hi = x - t * ln2_hi;
            lo = t * ln2_lo;
        }

        x = hi - lo;
        c = (hi - x) - lo;
    }
    // |x| < 2^(-25)
    else if (hx < 0x33000000) {
        if (hx < 0x00800000) {
            mem.doNotOptimizeAway(x * x);
        }
        return x;
    } else {
        k = 0;
    }

    const hfx = 0.5 * x;
    const hxs = x * hfx;
    const r1 = 1.0 + hxs * (Q1 + hxs * Q2);
    const t = 3.0 - r1 * hfx;
    var e = hxs * ((r1 - t) / (6.0 - x * t));

    // c is 0
    if (k == 0) {
        return x - (x * e - hxs);
    }

    e = x * (e - c) - c;
    e -= hxs;

    // exp(x) ~ 2^k (x_reduced - e + 1)
    if (k == -1) {
        return 0.5 * (x - e) - 0.5;
    }
    if (k == 1) {
        if (x < -0.25) {
            return -2.0 * (e - (x + 0.5));
        } else {
            return 1.0 + 2.0 * (x - e);
        }
    }

    const twopk = @as(f32, @bitCast(@as(u32, @intCast((0x7F +% k) << 23))));

    if (k < 0 or k > 56) {
        var y = x - e + 1.0;
        if (k == 128) {
            y = y * 2.0 * 0x1.0p127;
        } else {
            y = y * twopk;
        }

        return y - 1.0;
    }

    const uf: f32 = @bitCast(@as(u32, @intCast(0x7F -% k)) << 23);
    if (k < 23) {
        return (x - e + (1 - uf)) * twopk;
    } else {
        return (x - (e + uf) + 1) * twopk;
    }
}

fn expm1_64(x_: f64) f64 {
    if (math.isNan(x_))
        return math.nan(f64);

    const o_threshold: f64 = 7.09782712893383973096e+02;
    const ln2_hi: f64 = 6.93147180369123816490e-01;
    const ln2_lo: f64 = 1.90821492927058770002e-10;
    const invln2: f64 = 1.44269504088896338700e+00;
    const Q1: f64 = -3.33333333333331316428e-02;
    const Q2: f64 = 1.58730158725481460165e-03;
    const Q3: f64 = -7.93650757867487942473e-05;
    const Q4: f64 = 4.00821782732936239552e-06;
    const Q5: f64 = -2.01099218183624371326e-07;

    var x = x_;
    const ux = @as(u64, @bitCast(x));
    const hx = @as(u32, @intCast(ux >> 32)) & 0x7FFFFFFF;
    const sign = ux >> 63;

    if (math.isNegativeInf(x)) {
        return -1.0;
    }

    // |x| >= 56 * ln2
    if (hx >= 0x4043687A) {
        // exp1md(nan) = nan
        if (hx > 0x7FF00000) {
            return x;
        }
        // exp1md(-ve) = -1
        if (sign != 0) {
            return -1;
        }
        if (x > o_threshold) {
            math.raiseOverflow();
            return math.inf(f64);
        }
    }

    var hi: f64 = undefined;
    var lo: f64 = undefined;
    var c: f64 = undefined;
    var k: i32 = undefined;

    // |x| > 0.5 * ln2
    if (hx > 0x3FD62E42) {
        // |x| < 1.5 * ln2
        if (hx < 0x3FF0A2B2) {
            if (sign == 0) {
                hi = x - ln2_hi;
                lo = ln2_lo;
                k = 1;
            } else {
                hi = x + ln2_hi;
                lo = -ln2_lo;
                k = -1;
            }
        } else {
            var kf = invln2 * x;
            if (sign != 0) {
                kf -= 0.5;
            } else {
                kf += 0.5;
            }

            k = @as(i32, @intFromFloat(kf));
            const t = @as(f64, @floatFromInt(k));
            hi = x - t * ln2_hi;
            lo = t * ln2_lo;
        }

        x = hi - lo;
        c = (hi - x) - lo;
    }
    // |x| < 2^(-54)
    else if (hx < 0x3C900000) {
        if (hx < 0x00100000) {
            mem.doNotOptimizeAway(@as(f32, @floatCast(x)));
        }
        return x;
    } else {
        k = 0;
    }

    const hfx = 0.5 * x;
    const hxs = x * hfx;
    const r1 = 1.0 + hxs * (Q1 + hxs * (Q2 + hxs * (Q3 + hxs * (Q4 + hxs * Q5))));
    const t = 3.0 - r1 * hfx;
    var e = hxs * ((r1 - t) / (6.0 - x * t));

    // c is 0
    if (k == 0) {
        return x - (x * e - hxs);
    }

    e = x * (e - c) - c;
    e -= hxs;

    // exp(x) ~ 2^k (x_reduced - e + 1)
    if (k == -1) {
        return 0.5 * (x - e) - 0.5;
    }
    if (k == 1) {
        if (x < -0.25) {
            return -2.0 * (e - (x + 0.5));
        } else {
            return 1.0 + 2.0 * (x - e);
        }
    }

    const twopk = @as(f64, @bitCast(@as(u64, @intCast(0x3FF +% k)) << 52));

    if (k < 0 or k > 56) {
        var y = x - e + 1.0;
        if (k == 1024) {
            y = y * 2.0 * 0x1.0p1023;
        } else {
            y = y * twopk;
        }

        return y - 1.0;
    }

    const uf = @as(f64, @bitCast(@as(u64, @intCast(0x3FF -% k)) << 52));
    if (k < 20) {
        return (x - e + (1 - uf)) * twopk;
    } else {
        return (x - (e + uf) + 1) * twopk;
    }
}

test "expm1_32() special" {
    try expect(math.isPositiveZero(expm1_32(0.0)));
    try expect(math.isNegativeZero(expm1_32(-0.0)));
    try expectEqual(expm1_32(math.ln2), 1.0);
    try expectEqual(expm1_32(math.inf(f32)), math.inf(f32));
    try expectEqual(expm1_32(-math.inf(f32)), -1.0);
    try expect(math.isNan(expm1_32(math.nan(f32))));
    try expect(math.isNan(expm1_32(math.snan(f32))));
}

test "expm1_32() sanity" {
    try expectEqual(expm1_32(-0x1.0223a0p+3), -0x1.ffd6e0p-1);
    try expectEqual(expm1_32(0x1.161868p+2), 0x1.30712ap+6);
    try expectEqual(expm1_32(-0x1.0c34b4p+3), -0x1.ffe1fap-1);
    try expectEqual(expm1_32(-0x1.a206f0p+2), -0x1.ff4116p-1);
    try expectEqual(expm1_32(0x1.288bbcp+3), 0x1.4ab480p+13); // Disagrees with GCC in last bit
    try expectEqual(expm1_32(0x1.52efd0p-1), 0x1.e09536p-1);
    try expectEqual(expm1_32(-0x1.a05cc8p-2), -0x1.561c3ep-2);
    try expectEqual(expm1_32(0x1.1f9efap-1), 0x1.81ec4ep-1);
    try expectEqual(expm1_32(0x1.8c5db0p-1), 0x1.2b3364p+0);
    try expectEqual(expm1_32(-0x1.5b86eap-1), -0x1.f8951ap-2);
}

test "expm1_32() boundary" {
    // TODO: The last value before inf is actually 0x1.62e300p+6 -> 0x1.ff681ep+127
    // try expectEqual(expm1_32(0x1.62e42ep+6), 0x1.ffff08p+127); // Last value before result is inf
    try expectEqual(expm1_32(0x1.62e430p+6), math.inf(f32)); // First value that gives inf
    try expectEqual(expm1_32(0x1.fffffep+127), math.inf(f32)); // Max input value
    try expectEqual(expm1_32(0x1p-149), 0x1p-149); // Min positive input value
    try expectEqual(expm1_32(-0x1p-149), -0x1p-149); // Min negative input value
    try expectEqual(expm1_32(0x1p-126), 0x1p-126); // First positive subnormal input
    try expectEqual(expm1_32(-0x1p-126), -0x1p-126); // First negative subnormal input
    try expectEqual(expm1_32(0x1.fffffep-125), 0x1.fffffep-125); // Last positive value before subnormal
    try expectEqual(expm1_32(-0x1.fffffep-125), -0x1.fffffep-125); // Last negative value before subnormal
    try expectEqual(expm1_32(-0x1.154244p+4), -0x1.fffffep-1); // Last value before result is -1
    try expectEqual(expm1_32(-0x1.154246p+4), -1); // First value where result is -1
}

test "expm1_64() special" {
    try expect(math.isPositiveZero(expm1_64(0.0)));
    try expect(math.isNegativeZero(expm1_64(-0.0)));
    try expectEqual(expm1_64(math.ln2), 1.0);
    try expectEqual(expm1_64(math.inf(f64)), math.inf(f64));
    try expectEqual(expm1_64(-math.inf(f64)), -1.0);
    try expect(math.isNan(expm1_64(math.nan(f64))));
    try expect(math.isNan(expm1_64(math.snan(f64))));
}

test "expm1_64() sanity" {
    try expectEqual(expm1_64(-0x1.02239f3c6a8f1p+3), -0x1.ffd6df9b02b3ep-1);
    try expectEqual(expm1_64(0x1.161868e18bc67p+2), 0x1.30712ed238c04p+6);
    try expectEqual(expm1_64(-0x1.0c34b3e01e6e7p+3), -0x1.ffe1f94e493e7p-1);
    try expectEqual(expm1_64(-0x1.a206f0a19dcc4p+2), -0x1.ff4115c03f78dp-1);
    try expectEqual(expm1_64(0x1.288bbb0d6a1e6p+3), 0x1.4ab477496e07ep+13);
    try expectEqual(expm1_64(0x1.52efd0cd80497p-1), 0x1.e095382100a01p-1);
    try expectEqual(expm1_64(-0x1.a05cc754481d1p-2), -0x1.561c3e0582be6p-2);
    try expectEqual(expm1_64(0x1.1f9ef934745cbp-1), 0x1.81ec4cd4d4a8fp-1);
    try expectEqual(expm1_64(0x1.8c5db097f7442p-1), 0x1.2b3363a944bf7p+0);
    try expectEqual(expm1_64(-0x1.5b86ea8118a0ep-1), -0x1.f8951aebffbafp-2);
}

test "expm1_64() boundary" {
    try expectEqual(expm1_64(0x1.62e42fefa39efp+9), 0x1.fffffffffff2ap+1023); // Last value before result is inf
    try expectEqual(expm1_64(0x1.62e42fefa39f0p+9), math.inf(f64)); // First value that gives inf
    try expectEqual(expm1_64(0x1.fffffffffffffp+1023), math.inf(f64)); // Max input value
    try expectEqual(expm1_64(0x1p-1074), 0x1p-1074); // Min positive input value
    try expectEqual(expm1_64(-0x1p-1074), -0x1p-1074); // Min negative input value
    try expectEqual(expm1_64(0x1p-1022), 0x1p-1022); // First positive subnormal input
    try expectEqual(expm1_64(-0x1p-1022), -0x1p-1022); // First negative subnormal input
    try expectEqual(expm1_64(0x1.fffffffffffffp-1021), 0x1.fffffffffffffp-1021); // Last positive value before subnormal
    try expectEqual(expm1_64(-0x1.fffffffffffffp-1021), -0x1.fffffffffffffp-1021); // Last negative value before subnormal
    try expectEqual(expm1_64(-0x1.2b708872320e1p+5), -0x1.fffffffffffffp-1); // Last value before result is -1
    try expectEqual(expm1_64(-0x1.2b708872320e2p+5), -1); // First value where result is -1
}

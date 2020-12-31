// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/acosf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/acos.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the arc-cosine of x.
///
/// Special cases:
///  - acos(x)   = nan if x < -1 or x > 1
pub fn acos(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => acos32(x),
        f64 => acos64(x),
        else => @compileError("acos not implemented for " ++ @typeName(T)),
    };
}

fn r32(z: f32) f32 {
    const pS0 = 1.6666586697e-01;
    const pS1 = -4.2743422091e-02;
    const pS2 = -8.6563630030e-03;
    const qS1 = -7.0662963390e-01;

    const p = z * (pS0 + z * (pS1 + z * pS2));
    const q = 1.0 + z * qS1;
    return p / q;
}

fn acos32(x: f32) f32 {
    const pio2_hi = 1.5707962513e+00;
    const pio2_lo = 7.5497894159e-08;

    const hx: u32 = @bitCast(u32, x);
    const ix: u32 = hx & 0x7FFFFFFF;

    // |x| >= 1 or nan
    if (ix >= 0x3F800000) {
        if (ix == 0x3F800000) {
            if (hx >> 31 != 0) {
                return 2.0 * pio2_hi + 0x1.0p-120;
            } else {
                return 0.0;
            }
        } else {
            return math.nan(f32);
        }
    }

    // |x| < 0.5
    if (ix < 0x3F000000) {
        if (ix <= 0x32800000) { // |x| < 2^(-26)
            return pio2_hi + 0x1.0p-120;
        } else {
            return pio2_hi - (x - (pio2_lo - x * r32(x * x)));
        }
    }

    // x < -0.5
    if (hx >> 31 != 0) {
        const z = (1 + x) * 0.5;
        const s = math.sqrt(z);
        const w = r32(z) * s - pio2_lo;
        return 2 * (pio2_hi - (s + w));
    }

    // x > 0.5
    const z = (1.0 - x) * 0.5;
    const s = math.sqrt(z);
    const jx = @bitCast(u32, s);
    const df = @bitCast(f32, jx & 0xFFFFF000);
    const c = (z - df * df) / (s + df);
    const w = r32(z) * s + c;
    return 2 * (df + w);
}

fn r64(z: f64) f64 {
    const pS0: f64 = 1.66666666666666657415e-01;
    const pS1: f64 = -3.25565818622400915405e-01;
    const pS2: f64 = 2.01212532134862925881e-01;
    const pS3: f64 = -4.00555345006794114027e-02;
    const pS4: f64 = 7.91534994289814532176e-04;
    const pS5: f64 = 3.47933107596021167570e-05;
    const qS1: f64 = -2.40339491173441421878e+00;
    const qS2: f64 = 2.02094576023350569471e+00;
    const qS3: f64 = -6.88283971605453293030e-01;
    const qS4: f64 = 7.70381505559019352791e-02;

    const p = z * (pS0 + z * (pS1 + z * (pS2 + z * (pS3 + z * (pS4 + z * pS5)))));
    const q = 1.0 + z * (qS1 + z * (qS2 + z * (qS3 + z * qS4)));
    return p / q;
}

fn acos64(x: f64) f64 {
    const pio2_hi: f64 = 1.57079632679489655800e+00;
    const pio2_lo: f64 = 6.12323399573676603587e-17;

    const ux = @bitCast(u64, x);
    const hx = @intCast(u32, ux >> 32);
    const ix = hx & 0x7FFFFFFF;

    // |x| >= 1 or nan
    if (ix >= 0x3FF00000) {
        const lx = @intCast(u32, ux & 0xFFFFFFFF);

        // acos(1) = 0, acos(-1) = pi
        if ((ix - 0x3FF00000) | lx == 0) {
            if (hx >> 31 != 0) {
                return 2 * pio2_hi + 0x1.0p-120;
            } else {
                return 0;
            }
        }

        return math.nan(f32);
    }

    // |x| < 0.5
    if (ix < 0x3FE00000) {
        // |x| < 2^(-57)
        if (ix <= 0x3C600000) {
            return pio2_hi + 0x1.0p-120;
        } else {
            return pio2_hi - (x - (pio2_lo - x * r64(x * x)));
        }
    }

    // x < -0.5
    if (hx >> 31 != 0) {
        const z = (1.0 + x) * 0.5;
        const s = math.sqrt(z);
        const w = r64(z) * s - pio2_lo;
        return 2 * (pio2_hi - (s + w));
    }

    // x > 0.5
    const z = (1.0 - x) * 0.5;
    const s = math.sqrt(z);
    const jx = @bitCast(u64, s);
    const df = @bitCast(f64, jx & 0xFFFFFFFF00000000);
    const c = (z - df * df) / (s + df);
    const w = r64(z) * s + c;
    return 2 * (df + w);
}

test "math.acos" {
    expect(acos(@as(f32, 0.0)) == acos32(0.0));
    expect(acos(@as(f64, 0.0)) == acos64(0.0));
}

test "math.acos32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, acos32(0.0), 1.570796, epsilon));
    expect(math.approxEqAbs(f32, acos32(0.2), 1.369438, epsilon));
    expect(math.approxEqAbs(f32, acos32(0.3434), 1.220262, epsilon));
    expect(math.approxEqAbs(f32, acos32(0.5), 1.047198, epsilon));
    expect(math.approxEqAbs(f32, acos32(0.8923), 0.468382, epsilon));
    expect(math.approxEqAbs(f32, acos32(-0.2), 1.772154, epsilon));
}

test "math.acos64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, acos64(0.0), 1.570796, epsilon));
    expect(math.approxEqAbs(f64, acos64(0.2), 1.369438, epsilon));
    expect(math.approxEqAbs(f64, acos64(0.3434), 1.220262, epsilon));
    expect(math.approxEqAbs(f64, acos64(0.5), 1.047198, epsilon));
    expect(math.approxEqAbs(f64, acos64(0.8923), 0.468382, epsilon));
    expect(math.approxEqAbs(f64, acos64(-0.2), 1.772154, epsilon));
}

test "math.acos32.special" {
    expect(math.isNan(acos32(-2)));
    expect(math.isNan(acos32(1.5)));
}

test "math.acos64.special" {
    expect(math.isNan(acos64(-2)));
    expect(math.isNan(acos64(1.5)));
}

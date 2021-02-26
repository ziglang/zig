// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/atanf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/atan.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the arc-tangent of x.
///
/// Special Cases:
///  - atan(+-0)   = +-0
///  - atan(+-inf) = +-pi/2
pub fn atan(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => atan32(x),
        f64 => atan64(x),
        else => @compileError("atan not implemented for " ++ @typeName(T)),
    };
}

fn atan32(x_: f32) f32 {
    const atanhi = [_]f32{
        4.6364760399e-01, // atan(0.5)hi
        7.8539812565e-01, // atan(1.0)hi
        9.8279368877e-01, // atan(1.5)hi
        1.5707962513e+00, // atan(inf)hi
    };

    const atanlo = [_]f32{
        5.0121582440e-09, // atan(0.5)lo
        3.7748947079e-08, // atan(1.0)lo
        3.4473217170e-08, // atan(1.5)lo
        7.5497894159e-08, // atan(inf)lo
    };

    const aT = [_]f32{
        3.3333328366e-01,
        -1.9999158382e-01,
        1.4253635705e-01,
        -1.0648017377e-01,
        6.1687607318e-02,
    };

    var x = x_;
    var ix: u32 = @bitCast(u32, x);
    const sign = ix >> 31;
    ix &= 0x7FFFFFFF;

    // |x| >= 2^26
    if (ix >= 0x4C800000) {
        if (math.isNan(x)) {
            return x;
        } else {
            const z = atanhi[3] + 0x1.0p-120;
            return if (sign != 0) -z else z;
        }
    }

    var id: ?usize = undefined;

    // |x| < 0.4375
    if (ix < 0x3EE00000) {
        // |x| < 2^(-12)
        if (ix < 0x39800000) {
            if (ix < 0x00800000) {
                math.doNotOptimizeAway(x * x);
            }
            return x;
        }
        id = null;
    } else {
        x = math.fabs(x);
        // |x| < 1.1875
        if (ix < 0x3F980000) {
            // 7/16 <= |x| < 11/16
            if (ix < 0x3F300000) {
                id = 0;
                x = (2.0 * x - 1.0) / (2.0 + x);
            }
            // 11/16 <= |x| < 19/16
            else {
                id = 1;
                x = (x - 1.0) / (x + 1.0);
            }
        } else {
            // |x| < 2.4375
            if (ix < 0x401C0000) {
                id = 2;
                x = (x - 1.5) / (1.0 + 1.5 * x);
            }
            // 2.4375 <= |x| < 2^26
            else {
                id = 3;
                x = -1.0 / x;
            }
        }
    }

    const z = x * x;
    const w = z * z;
    const s1 = z * (aT[0] + w * (aT[2] + w * aT[4]));
    const s2 = w * (aT[1] + w * aT[3]);

    if (id) |id_value| {
        const zz = atanhi[id_value] - ((x * (s1 + s2) - atanlo[id_value]) - x);
        return if (sign != 0) -zz else zz;
    } else {
        return x - x * (s1 + s2);
    }
}

fn atan64(x_: f64) f64 {
    const atanhi = [_]f64{
        4.63647609000806093515e-01, // atan(0.5)hi
        7.85398163397448278999e-01, // atan(1.0)hi
        9.82793723247329054082e-01, // atan(1.5)hi
        1.57079632679489655800e+00, // atan(inf)hi
    };

    const atanlo = [_]f64{
        2.26987774529616870924e-17, // atan(0.5)lo
        3.06161699786838301793e-17, // atan(1.0)lo
        1.39033110312309984516e-17, // atan(1.5)lo
        6.12323399573676603587e-17, // atan(inf)lo
    };

    const aT = [_]f64{
        3.33333333333329318027e-01,
        -1.99999999998764832476e-01,
        1.42857142725034663711e-01,
        -1.11111104054623557880e-01,
        9.09088713343650656196e-02,
        -7.69187620504482999495e-02,
        6.66107313738753120669e-02,
        -5.83357013379057348645e-02,
        4.97687799461593236017e-02,
        -3.65315727442169155270e-02,
        1.62858201153657823623e-02,
    };

    var x = x_;
    var ux = @bitCast(u64, x);
    var ix = @intCast(u32, ux >> 32);
    const sign = ix >> 31;
    ix &= 0x7FFFFFFF;

    // |x| >= 2^66
    if (ix >= 0x44100000) {
        if (math.isNan(x)) {
            return x;
        } else {
            const z = atanhi[3] + 0x1.0p-120;
            return if (sign != 0) -z else z;
        }
    }

    var id: ?usize = undefined;

    // |x| < 0.4375
    if (ix < 0x3DFC0000) {
        // |x| < 2^(-27)
        if (ix < 0x3E400000) {
            if (ix < 0x00100000) {
                math.doNotOptimizeAway(@floatCast(f32, x));
            }
            return x;
        }
        id = null;
    } else {
        x = math.fabs(x);
        // |x| < 1.1875
        if (ix < 0x3FF30000) {
            // 7/16 <= |x| < 11/16
            if (ix < 0x3FE60000) {
                id = 0;
                x = (2.0 * x - 1.0) / (2.0 + x);
            }
            // 11/16 <= |x| < 19/16
            else {
                id = 1;
                x = (x - 1.0) / (x + 1.0);
            }
        } else {
            // |x| < 2.4375
            if (ix < 0x40038000) {
                id = 2;
                x = (x - 1.5) / (1.0 + 1.5 * x);
            }
            // 2.4375 <= |x| < 2^66
            else {
                id = 3;
                x = -1.0 / x;
            }
        }
    }

    const z = x * x;
    const w = z * z;
    const s1 = z * (aT[0] + w * (aT[2] + w * (aT[4] + w * (aT[6] + w * (aT[8] + w * aT[10])))));
    const s2 = w * (aT[1] + w * (aT[3] + w * (aT[5] + w * (aT[7] + w * aT[9]))));

    if (id) |id_value| {
        const zz = atanhi[id_value] - ((x * (s1 + s2) - atanlo[id_value]) - x);
        return if (sign != 0) -zz else zz;
    } else {
        return x - x * (s1 + s2);
    }
}

test "math.atan" {
    expect(@bitCast(u32, atan(@as(f32, 0.2))) == @bitCast(u32, atan32(0.2)));
    expect(atan(@as(f64, 0.2)) == atan64(0.2));
}

test "math.atan32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, atan32(0.2), 0.197396, epsilon));
    expect(math.approxEqAbs(f32, atan32(-0.2), -0.197396, epsilon));
    expect(math.approxEqAbs(f32, atan32(0.3434), 0.330783, epsilon));
    expect(math.approxEqAbs(f32, atan32(0.8923), 0.728545, epsilon));
    expect(math.approxEqAbs(f32, atan32(1.5), 0.982794, epsilon));
}

test "math.atan64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, atan64(0.2), 0.197396, epsilon));
    expect(math.approxEqAbs(f64, atan64(-0.2), -0.197396, epsilon));
    expect(math.approxEqAbs(f64, atan64(0.3434), 0.330783, epsilon));
    expect(math.approxEqAbs(f64, atan64(0.8923), 0.728545, epsilon));
    expect(math.approxEqAbs(f64, atan64(1.5), 0.982794, epsilon));
}

test "math.atan32.special" {
    const epsilon = 0.000001;

    expect(atan32(0.0) == 0.0);
    expect(atan32(-0.0) == -0.0);
    expect(math.approxEqAbs(f32, atan32(math.inf(f32)), math.pi / 2.0, epsilon));
    expect(math.approxEqAbs(f32, atan32(-math.inf(f32)), -math.pi / 2.0, epsilon));
}

test "math.atan64.special" {
    const epsilon = 0.000001;

    expect(atan64(0.0) == 0.0);
    expect(atan64(-0.0) == -0.0);
    expect(math.approxEqAbs(f64, atan64(math.inf(f64)), math.pi / 2.0, epsilon));
    expect(math.approxEqAbs(f64, atan64(-math.inf(f64)), -math.pi / 2.0, epsilon));
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from go, which is licensed under a BSD-3 license.
// https://golang.org/LICENSE
//
// https://golang.org/src/math/tan.go

const builtin = @import("builtin");
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the tangent of the radian value x.
///
/// Special Cases:
///  - tan(+-0)   = +-0
///  - tan(+-inf) = nan
///  - tan(nan)   = nan
pub fn tan(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => tan_(f32, x),
        f64 => tan_(f64, x),
        else => @compileError("tan not implemented for " ++ @typeName(T)),
    };
}

const Tp0 = -1.30936939181383777646E4;
const Tp1 = 1.15351664838587416140E6;
const Tp2 = -1.79565251976484877988E7;

const Tq1 = 1.36812963470692954678E4;
const Tq2 = -1.32089234440210967447E6;
const Tq3 = 2.50083801823357915839E7;
const Tq4 = -5.38695755929454629881E7;

const pi4a = 7.85398125648498535156e-1;
const pi4b = 3.77489470793079817668E-8;
const pi4c = 2.69515142907905952645E-15;
const m4pi = 1.273239544735162542821171882678754627704620361328125;

fn tan_(comptime T: type, x_: T) T {
    const I = std.meta.Int(.signed, @typeInfo(T).Float.bits);

    var x = x_;
    if (x == 0 or math.isNan(x)) {
        return x;
    }
    if (math.isInf(x)) {
        return math.nan(T);
    }

    var sign = x < 0;
    x = math.fabs(x);

    var y = math.floor(x * m4pi);
    var j = @floatToInt(I, y);

    if (j & 1 == 1) {
        j += 1;
        y += 1;
    }

    const z = ((x - y * pi4a) - y * pi4b) - y * pi4c;
    const w = z * z;

    var r = if (w > 1e-14)
        z + z * (w * ((Tp0 * w + Tp1) * w + Tp2) / ((((w + Tq1) * w + Tq2) * w + Tq3) * w + Tq4))
    else
        z;

    if (j & 2 == 2) {
        r = -1 / r;
    }

    return if (sign) -r else r;
}

test "math.tan" {
    expect(tan(@as(f32, 0.0)) == tan_(f32, 0.0));
    expect(tan(@as(f64, 0.0)) == tan_(f64, 0.0));
}

test "math.tan32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, tan_(f32, 0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f32, tan_(f32, 0.2), 0.202710, epsilon));
    expect(math.approxEqAbs(f32, tan_(f32, 0.8923), 1.240422, epsilon));
    expect(math.approxEqAbs(f32, tan_(f32, 1.5), 14.101420, epsilon));
    expect(math.approxEqAbs(f32, tan_(f32, 37.45), -0.254397, epsilon));
    expect(math.approxEqAbs(f32, tan_(f32, 89.123), 2.285852, epsilon));
}

test "math.tan64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, tan_(f64, 0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f64, tan_(f64, 0.2), 0.202710, epsilon));
    expect(math.approxEqAbs(f64, tan_(f64, 0.8923), 1.240422, epsilon));
    expect(math.approxEqAbs(f64, tan_(f64, 1.5), 14.101420, epsilon));
    expect(math.approxEqAbs(f64, tan_(f64, 37.45), -0.254397, epsilon));
    expect(math.approxEqAbs(f64, tan_(f64, 89.123), 2.2858376, epsilon));
}

test "math.tan32.special" {
    expect(tan_(f32, 0.0) == 0.0);
    expect(tan_(f32, -0.0) == -0.0);
    expect(math.isNan(tan_(f32, math.inf(f32))));
    expect(math.isNan(tan_(f32, -math.inf(f32))));
    expect(math.isNan(tan_(f32, math.nan(f32))));
}

test "math.tan64.special" {
    expect(tan_(f64, 0.0) == 0.0);
    expect(tan_(f64, -0.0) == -0.0);
    expect(math.isNan(tan_(f64, math.inf(f64))));
    expect(math.isNan(tan_(f64, -math.inf(f64))));
    expect(math.isNan(tan_(f64, math.nan(f64))));
}

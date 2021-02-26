// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from go, which is licensed under a BSD-3 license.
// https://golang.org/LICENSE
//
// https://golang.org/src/math/sin.go

const builtin = @import("builtin");
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the sine of the radian value x.
///
/// Special Cases:
///  - sin(+-0)   = +-0
///  - sin(+-inf) = nan
///  - sin(nan)   = nan
pub fn sin(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => sin_(T, x),
        f64 => sin_(T, x),
        else => @compileError("sin not implemented for " ++ @typeName(T)),
    };
}

// sin polynomial coefficients
const S0 = 1.58962301576546568060E-10;
const S1 = -2.50507477628578072866E-8;
const S2 = 2.75573136213857245213E-6;
const S3 = -1.98412698295895385996E-4;
const S4 = 8.33333333332211858878E-3;
const S5 = -1.66666666666666307295E-1;

// cos polynomial coeffiecients
const C0 = -1.13585365213876817300E-11;
const C1 = 2.08757008419747316778E-9;
const C2 = -2.75573141792967388112E-7;
const C3 = 2.48015872888517045348E-5;
const C4 = -1.38888888888730564116E-3;
const C5 = 4.16666666666665929218E-2;

const pi4a = 7.85398125648498535156e-1;
const pi4b = 3.77489470793079817668E-8;
const pi4c = 2.69515142907905952645E-15;
const m4pi = 1.273239544735162542821171882678754627704620361328125;

fn sin_(comptime T: type, x_: T) T {
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

    j &= 7;
    if (j > 3) {
        j -= 4;
        sign = !sign;
    }

    const z = ((x - y * pi4a) - y * pi4b) - y * pi4c;
    const w = z * z;

    const r = if (j == 1 or j == 2)
        1.0 - 0.5 * w + w * w * (C5 + w * (C4 + w * (C3 + w * (C2 + w * (C1 + w * C0)))))
    else
        z + z * w * (S5 + w * (S4 + w * (S3 + w * (S2 + w * (S1 + w * S0)))));

    return if (sign) -r else r;
}

test "math.sin" {
    expect(sin(@as(f32, 0.0)) == sin_(f32, 0.0));
    expect(sin(@as(f64, 0.0)) == sin_(f64, 0.0));
    expect(comptime (math.sin(@as(f64, 2))) == math.sin(@as(f64, 2)));
}

test "math.sin32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, sin_(f32, 0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f32, sin_(f32, 0.2), 0.198669, epsilon));
    expect(math.approxEqAbs(f32, sin_(f32, 0.8923), 0.778517, epsilon));
    expect(math.approxEqAbs(f32, sin_(f32, 1.5), 0.997495, epsilon));
    expect(math.approxEqAbs(f32, sin_(f32, -1.5), -0.997495, epsilon));
    expect(math.approxEqAbs(f32, sin_(f32, 37.45), -0.246544, epsilon));
    expect(math.approxEqAbs(f32, sin_(f32, 89.123), 0.916166, epsilon));
}

test "math.sin64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, sin_(f64, 0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f64, sin_(f64, 0.2), 0.198669, epsilon));
    expect(math.approxEqAbs(f64, sin_(f64, 0.8923), 0.778517, epsilon));
    expect(math.approxEqAbs(f64, sin_(f64, 1.5), 0.997495, epsilon));
    expect(math.approxEqAbs(f64, sin_(f64, -1.5), -0.997495, epsilon));
    expect(math.approxEqAbs(f64, sin_(f64, 37.45), -0.246543, epsilon));
    expect(math.approxEqAbs(f64, sin_(f64, 89.123), 0.916166, epsilon));
}

test "math.sin32.special" {
    expect(sin_(f32, 0.0) == 0.0);
    expect(sin_(f32, -0.0) == -0.0);
    expect(math.isNan(sin_(f32, math.inf(f32))));
    expect(math.isNan(sin_(f32, -math.inf(f32))));
    expect(math.isNan(sin_(f32, math.nan(f32))));
}

test "math.sin64.special" {
    expect(sin_(f64, 0.0) == 0.0);
    expect(sin_(f64, -0.0) == -0.0);
    expect(math.isNan(sin_(f64, math.inf(f64))));
    expect(math.isNan(sin_(f64, -math.inf(f64))));
    expect(math.isNan(sin_(f64, math.nan(f64))));
}

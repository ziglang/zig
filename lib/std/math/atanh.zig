// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/atanhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/atanh.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns the hyperbolic arc-tangent of x.
///
/// Special Cases:
///  - atanh(+-1) = +-inf with signal
///  - atanh(x)   = nan if |x| > 1 with signal
///  - atanh(nan) = nan
pub fn atanh(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => atanh_32(x),
        f64 => atanh_64(x),
        else => @compileError("atanh not implemented for " ++ @typeName(T)),
    };
}

// atanh(x) = log((1 + x) / (1 - x)) / 2 = log1p(2x / (1 - x)) / 2 ~= x + x^3 / 3 + o(x^5)
fn atanh_32(x: f32) f32 {
    const u = @bitCast(u32, x);
    const i = u & 0x7FFFFFFF;
    const s = u >> 31;

    var y = @bitCast(f32, i); // |x|

    if (y == 1.0) {
        return math.copysign(f32, math.inf(f32), x);
    }

    if (u < 0x3F800000 - (1 << 23)) {
        if (u < 0x3F800000 - (32 << 23)) {
            // underflow
            if (u < (1 << 23)) {
                math.doNotOptimizeAway(y * y);
            }
        }
        // |x| < 0.5
        else {
            y = 0.5 * math.log1p(2 * y + 2 * y * y / (1 - y));
        }
    } else {
        y = 0.5 * math.log1p(2 * (y / (1 - y)));
    }

    return if (s != 0) -y else y;
}

fn atanh_64(x: f64) f64 {
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    const s = u >> 63;

    var y = @bitCast(f64, u & (maxInt(u64) >> 1)); // |x|

    if (y == 1.0) {
        return math.copysign(f64, math.inf(f64), x);
    }

    if (e < 0x3FF - 1) {
        if (e < 0x3FF - 32) {
            // underflow
            if (e == 0) {
                math.doNotOptimizeAway(@floatCast(f32, y));
            }
        }
        // |x| < 0.5
        else {
            y = 0.5 * math.log1p(2 * y + 2 * y * y / (1 - y));
        }
    } else {
        y = 0.5 * math.log1p(2 * (y / (1 - y)));
    }

    return if (s != 0) -y else y;
}

test "math.atanh" {
    expect(atanh(@as(f32, 0.0)) == atanh_32(0.0));
    expect(atanh(@as(f64, 0.0)) == atanh_64(0.0));
}

test "math.atanh_32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, atanh_32(0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f32, atanh_32(0.2), 0.202733, epsilon));
    expect(math.approxEqAbs(f32, atanh_32(0.8923), 1.433099, epsilon));
}

test "math.atanh_64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, atanh_64(0.0), 0.0, epsilon));
    expect(math.approxEqAbs(f64, atanh_64(0.2), 0.202733, epsilon));
    expect(math.approxEqAbs(f64, atanh_64(0.8923), 1.433099, epsilon));
}

test "math.atanh32.special" {
    expect(math.isPositiveInf(atanh_32(1)));
    expect(math.isNegativeInf(atanh_32(-1)));
    expect(math.isSignalNan(atanh_32(1.5)));
    expect(math.isSignalNan(atanh_32(-1.5)));
    expect(math.isNan(atanh_32(math.nan(f32))));
}

test "math.atanh64.special" {
    expect(math.isPositiveInf(atanh_64(1)));
    expect(math.isNegativeInf(atanh_64(-1)));
    expect(math.isSignalNan(atanh_64(1.5)));
    expect(math.isSignalNan(atanh_64(-1.5)));
    expect(math.isNan(atanh_64(math.nan(f64))));
}

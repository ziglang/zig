// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/roundf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/round.c

const builtin = @import("builtin");
const expect = std.testing.expect;
const std = @import("../std.zig");
const math = std.math;

/// Returns x rounded to the nearest integer, rounding half away from zero.
///
/// Special Cases:
///  - round(+-0)   = +-0
///  - round(+-inf) = +-inf
///  - round(nan)   = nan
pub fn round(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => round32(x),
        f64 => round64(x),
        f128 => round128(x),
        else => @compileError("round not implemented for " ++ @typeName(T)),
    };
}

fn round32(x_: f32) f32 {
    var x = x_;
    const u = @bitCast(u32, x);
    const e = (u >> 23) & 0xFF;
    var y: f32 = undefined;

    if (e >= 0x7F + 23) {
        return x;
    }
    if (u >> 31 != 0) {
        x = -x;
    }
    if (e < 0x7F - 1) {
        math.doNotOptimizeAway(x + math.f32_toint);
        return 0 * @bitCast(f32, u);
    }

    y = x + math.f32_toint - math.f32_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 31 != 0) {
        return -y;
    } else {
        return y;
    }
}

fn round64(x_: f64) f64 {
    var x = x_;
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF + 52) {
        return x;
    }
    if (u >> 63 != 0) {
        x = -x;
    }
    if (e < 0x3ff - 1) {
        math.doNotOptimizeAway(x + math.f64_toint);
        return 0 * @bitCast(f64, u);
    }

    y = x + math.f64_toint - math.f64_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 63 != 0) {
        return -y;
    } else {
        return y;
    }
}

fn round128(x_: f128) f128 {
    var x = x_;
    const u = @bitCast(u128, x);
    const e = (u >> 112) & 0x7FFF;
    var y: f128 = undefined;

    if (e >= 0x3FFF + 112) {
        return x;
    }
    if (u >> 127 != 0) {
        x = -x;
    }
    if (e < 0x3FFF - 1) {
        math.doNotOptimizeAway(x + math.f64_toint);
        return 0 * @bitCast(f128, u);
    }

    y = x + math.f128_toint - math.f128_toint - x;
    if (y > 0.5) {
        y = y + x - 1;
    } else if (y <= -0.5) {
        y = y + x + 1;
    } else {
        y = y + x;
    }

    if (u >> 127 != 0) {
        return -y;
    } else {
        return y;
    }
}

test "math.round" {
    expect(round(@as(f32, 1.3)) == round32(1.3));
    expect(round(@as(f64, 1.3)) == round64(1.3));
    expect(round(@as(f128, 1.3)) == round128(1.3));
}

test "math.round32" {
    expect(round32(1.3) == 1.0);
    expect(round32(-1.3) == -1.0);
    expect(round32(0.2) == 0.0);
    expect(round32(1.8) == 2.0);
}

test "math.round64" {
    expect(round64(1.3) == 1.0);
    expect(round64(-1.3) == -1.0);
    expect(round64(0.2) == 0.0);
    expect(round64(1.8) == 2.0);
}

test "math.round128" {
    expect(round128(1.3) == 1.0);
    expect(round128(-1.3) == -1.0);
    expect(round128(0.2) == 0.0);
    expect(round128(1.8) == 2.0);
}

test "math.round32.special" {
    expect(round32(0.0) == 0.0);
    expect(round32(-0.0) == -0.0);
    expect(math.isPositiveInf(round32(math.inf(f32))));
    expect(math.isNegativeInf(round32(-math.inf(f32))));
    expect(math.isNan(round32(math.nan(f32))));
}

test "math.round64.special" {
    expect(round64(0.0) == 0.0);
    expect(round64(-0.0) == -0.0);
    expect(math.isPositiveInf(round64(math.inf(f64))));
    expect(math.isNegativeInf(round64(-math.inf(f64))));
    expect(math.isNan(round64(math.nan(f64))));
}

test "math.round128.special" {
    expect(round128(0.0) == 0.0);
    expect(round128(-0.0) == -0.0);
    expect(math.isPositiveInf(round128(math.inf(f128))));
    expect(math.isNegativeInf(round128(-math.inf(f128))));
    expect(math.isNan(round128(math.nan(f128))));
}

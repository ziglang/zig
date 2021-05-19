// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/ceilf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/ceil.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the least integer value greater than of equal to x.
///
/// Special Cases:
///  - ceil(+-0)   = +-0
///  - ceil(+-inf) = +-inf
///  - ceil(nan)   = nan
pub fn ceil(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => ceil32(x),
        f64 => ceil64(x),
        f128 => ceil128(x),
        else => @compileError("ceil not implemented for " ++ @typeName(T)),
    };
}

fn ceil32(x: f32) f32 {
    var u = @bitCast(u32, x);
    var e = @intCast(i32, (u >> 23) & 0xFF) - 0x7F;
    var m: u32 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 23) {
        return x;
    } else if (e >= 0) {
        m = @as(u32, 0x007FFFFF) >> @intCast(u5, e);
        if (u & m == 0) {
            return x;
        }
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 == 0) {
            u += m;
        }
        u &= ~m;
        return @bitCast(f32, u);
    } else {
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 != 0) {
            return -0.0;
        } else {
            return 1.0;
        }
    }
}

fn ceil64(x: f64) f64 {
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF + 52 or x == 0) {
        return x;
    }

    if (u >> 63 != 0) {
        y = x - math.f64_toint + math.f64_toint - x;
    } else {
        y = x + math.f64_toint - math.f64_toint - x;
    }

    if (e <= 0x3FF - 1) {
        math.doNotOptimizeAway(y);
        if (u >> 63 != 0) {
            return -0.0;
        } else {
            return 1.0;
        }
    } else if (y < 0) {
        return x + y + 1;
    } else {
        return x + y;
    }
}

fn ceil128(x: f128) f128 {
    const u = @bitCast(u128, x);
    const e = (u >> 112) & 0x7FFF;
    var y: f128 = undefined;

    if (e >= 0x3FFF + 112 or x == 0) return x;

    if (u >> 127 != 0) {
        y = x - math.f128_toint + math.f128_toint - x;
    } else {
        y = x + math.f128_toint - math.f128_toint - x;
    }

    if (e <= 0x3FFF - 1) {
        math.doNotOptimizeAway(y);
        if (u >> 127 != 0) {
            return -0.0;
        } else {
            return 1.0;
        }
    } else if (y < 0) {
        return x + y + 1;
    } else {
        return x + y;
    }
}

test "math.ceil" {
    try expect(ceil(@as(f32, 0.0)) == ceil32(0.0));
    try expect(ceil(@as(f64, 0.0)) == ceil64(0.0));
    try expect(ceil(@as(f128, 0.0)) == ceil128(0.0));
}

test "math.ceil32" {
    try expect(ceil32(1.3) == 2.0);
    try expect(ceil32(-1.3) == -1.0);
    try expect(ceil32(0.2) == 1.0);
}

test "math.ceil64" {
    try expect(ceil64(1.3) == 2.0);
    try expect(ceil64(-1.3) == -1.0);
    try expect(ceil64(0.2) == 1.0);
}

test "math.ceil128" {
    try expect(ceil128(1.3) == 2.0);
    try expect(ceil128(-1.3) == -1.0);
    try expect(ceil128(0.2) == 1.0);
}

test "math.ceil32.special" {
    try expect(ceil32(0.0) == 0.0);
    try expect(ceil32(-0.0) == -0.0);
    try expect(math.isPositiveInf(ceil32(math.inf(f32))));
    try expect(math.isNegativeInf(ceil32(-math.inf(f32))));
    try expect(math.isNan(ceil32(math.nan(f32))));
}

test "math.ceil64.special" {
    try expect(ceil64(0.0) == 0.0);
    try expect(ceil64(-0.0) == -0.0);
    try expect(math.isPositiveInf(ceil64(math.inf(f64))));
    try expect(math.isNegativeInf(ceil64(-math.inf(f64))));
    try expect(math.isNan(ceil64(math.nan(f64))));
}

test "math.ceil128.special" {
    try expect(ceil128(0.0) == 0.0);
    try expect(ceil128(-0.0) == -0.0);
    try expect(math.isPositiveInf(ceil128(math.inf(f128))));
    try expect(math.isNegativeInf(ceil128(-math.inf(f128))));
    try expect(math.isNan(ceil128(math.nan(f128))));
}

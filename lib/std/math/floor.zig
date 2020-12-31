// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/floorf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/floor.c

const builtin = @import("builtin");
const expect = std.testing.expect;
const std = @import("../std.zig");
const math = std.math;

/// Returns the greatest integer value less than or equal to x.
///
/// Special Cases:
///  - floor(+-0)   = +-0
///  - floor(+-inf) = +-inf
///  - floor(nan)   = nan
pub fn floor(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f16 => floor16(x),
        f32 => floor32(x),
        f64 => floor64(x),
        f128 => floor128(x),
        else => @compileError("floor not implemented for " ++ @typeName(T)),
    };
}

fn floor16(x: f16) f16 {
    var u = @bitCast(u16, x);
    const e = @intCast(i16, (u >> 10) & 31) - 15;
    var m: u16 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 10) {
        return x;
    }

    if (e >= 0) {
        m = @as(u16, 1023) >> @intCast(u4, e);
        if (u & m == 0) {
            return x;
        }
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 15 != 0) {
            u += m;
        }
        return @bitCast(f16, u & ~m);
    } else {
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 15 == 0) {
            return 0.0;
        } else {
            return -1.0;
        }
    }
}

fn floor32(x: f32) f32 {
    var u = @bitCast(u32, x);
    const e = @intCast(i32, (u >> 23) & 0xFF) - 0x7F;
    var m: u32 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 23) {
        return x;
    }

    if (e >= 0) {
        m = @as(u32, 0x007FFFFF) >> @intCast(u5, e);
        if (u & m == 0) {
            return x;
        }
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 != 0) {
            u += m;
        }
        return @bitCast(f32, u & ~m);
    } else {
        math.doNotOptimizeAway(x + 0x1.0p120);
        if (u >> 31 == 0) {
            return 0.0;
        } else {
            return -1.0;
        }
    }
}

fn floor64(x: f64) f64 {
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
            return -1.0;
        } else {
            return 0.0;
        }
    } else if (y > 0) {
        return x + y - 1;
    } else {
        return x + y;
    }
}

fn floor128(x: f128) f128 {
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
            return -1.0;
        } else {
            return 0.0;
        }
    } else if (y > 0) {
        return x + y - 1;
    } else {
        return x + y;
    }
}

test "math.floor" {
    expect(floor(@as(f16, 1.3)) == floor16(1.3));
    expect(floor(@as(f32, 1.3)) == floor32(1.3));
    expect(floor(@as(f64, 1.3)) == floor64(1.3));
    expect(floor(@as(f128, 1.3)) == floor128(1.3));
}

test "math.floor16" {
    expect(floor16(1.3) == 1.0);
    expect(floor16(-1.3) == -2.0);
    expect(floor16(0.2) == 0.0);
}

test "math.floor32" {
    expect(floor32(1.3) == 1.0);
    expect(floor32(-1.3) == -2.0);
    expect(floor32(0.2) == 0.0);
}

test "math.floor64" {
    expect(floor64(1.3) == 1.0);
    expect(floor64(-1.3) == -2.0);
    expect(floor64(0.2) == 0.0);
}

test "math.floor128" {
    expect(floor128(1.3) == 1.0);
    expect(floor128(-1.3) == -2.0);
    expect(floor128(0.2) == 0.0);
}

test "math.floor16.special" {
    expect(floor16(0.0) == 0.0);
    expect(floor16(-0.0) == -0.0);
    expect(math.isPositiveInf(floor16(math.inf(f16))));
    expect(math.isNegativeInf(floor16(-math.inf(f16))));
    expect(math.isNan(floor16(math.nan(f16))));
}

test "math.floor32.special" {
    expect(floor32(0.0) == 0.0);
    expect(floor32(-0.0) == -0.0);
    expect(math.isPositiveInf(floor32(math.inf(f32))));
    expect(math.isNegativeInf(floor32(-math.inf(f32))));
    expect(math.isNan(floor32(math.nan(f32))));
}

test "math.floor64.special" {
    expect(floor64(0.0) == 0.0);
    expect(floor64(-0.0) == -0.0);
    expect(math.isPositiveInf(floor64(math.inf(f64))));
    expect(math.isNegativeInf(floor64(-math.inf(f64))));
    expect(math.isNan(floor64(math.nan(f64))));
}

test "math.floor128.special" {
    expect(floor128(0.0) == 0.0);
    expect(floor128(-0.0) == -0.0);
    expect(math.isPositiveInf(floor128(math.inf(f128))));
    expect(math.isNegativeInf(floor128(-math.inf(f128))));
    expect(math.isNan(floor128(math.nan(f128))));
}

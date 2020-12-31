// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/ilogbf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/ilogb.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

/// Returns the binary exponent of x as an integer.
///
/// Special Cases:
///  - ilogb(+-inf) = maxInt(i32)
///  - ilogb(0)     = maxInt(i32)
///  - ilogb(nan)   = maxInt(i32)
pub fn ilogb(x: anytype) i32 {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => ilogb32(x),
        f64 => ilogb64(x),
        else => @compileError("ilogb not implemented for " ++ @typeName(T)),
    };
}

// NOTE: Should these be exposed publicly?
const fp_ilogbnan = -1 - @as(i32, maxInt(u32) >> 1);
const fp_ilogb0 = fp_ilogbnan;

fn ilogb32(x: f32) i32 {
    var u = @bitCast(u32, x);
    var e = @intCast(i32, (u >> 23) & 0xFF);

    // TODO: We should be able to merge this with the lower check.
    if (math.isNan(x)) {
        return maxInt(i32);
    }

    if (e == 0) {
        u <<= 9;
        if (u == 0) {
            math.raiseInvalid();
            return fp_ilogb0;
        }

        // subnormal
        e = -0x7F;
        while (u >> 31 == 0) : (u <<= 1) {
            e -= 1;
        }
        return e;
    }

    if (e == 0xFF) {
        math.raiseInvalid();
        if (u << 9 != 0) {
            return fp_ilogbnan;
        } else {
            return maxInt(i32);
        }
    }

    return e - 0x7F;
}

fn ilogb64(x: f64) i32 {
    var u = @bitCast(u64, x);
    var e = @intCast(i32, (u >> 52) & 0x7FF);

    if (math.isNan(x)) {
        return maxInt(i32);
    }

    if (e == 0) {
        u <<= 12;
        if (u == 0) {
            math.raiseInvalid();
            return fp_ilogb0;
        }

        // subnormal
        e = -0x3FF;
        while (u >> 63 == 0) : (u <<= 1) {
            e -= 1;
        }
        return e;
    }

    if (e == 0x7FF) {
        math.raiseInvalid();
        if (u << 12 != 0) {
            return fp_ilogbnan;
        } else {
            return maxInt(i32);
        }
    }

    return e - 0x3FF;
}

test "math.ilogb" {
    expect(ilogb(@as(f32, 0.2)) == ilogb32(0.2));
    expect(ilogb(@as(f64, 0.2)) == ilogb64(0.2));
}

test "math.ilogb32" {
    expect(ilogb32(0.0) == fp_ilogb0);
    expect(ilogb32(0.5) == -1);
    expect(ilogb32(0.8923) == -1);
    expect(ilogb32(10.0) == 3);
    expect(ilogb32(-123984) == 16);
    expect(ilogb32(2398.23) == 11);
}

test "math.ilogb64" {
    expect(ilogb64(0.0) == fp_ilogb0);
    expect(ilogb64(0.5) == -1);
    expect(ilogb64(0.8923) == -1);
    expect(ilogb64(10.0) == 3);
    expect(ilogb64(-123984) == 16);
    expect(ilogb64(2398.23) == 11);
}

test "math.ilogb32.special" {
    expect(ilogb32(math.inf(f32)) == maxInt(i32));
    expect(ilogb32(-math.inf(f32)) == maxInt(i32));
    expect(ilogb32(0.0) == minInt(i32));
    expect(ilogb32(math.nan(f32)) == maxInt(i32));
}

test "math.ilogb64.special" {
    expect(ilogb64(math.inf(f64)) == maxInt(i32));
    expect(ilogb64(-math.inf(f64)) == maxInt(i32));
    expect(ilogb64(0.0) == minInt(i32));
    expect(ilogb64(math.nan(f64)) == maxInt(i32));
}

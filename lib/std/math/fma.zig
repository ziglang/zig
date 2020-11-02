// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/fmaf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/fma.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns x * y + z with a single rounding error.
pub fn fma(comptime T: type, x: T, y: T, z: T) T {
    return switch (T) {
        f32 => fma32(x, y, z),
        f64 => fma64(x, y, z),
        else => @compileError("fma not implemented for " ++ @typeName(T)),
    };
}

fn fma32(x: f32, y: f32, z: f32) f32 {
    const xy = @as(f64, x) * y;
    const xy_z = xy + z;
    const u = @bitCast(u64, xy_z);
    const e = (u >> 52) & 0x7FF;

    if ((u & 0x1FFFFFFF) != 0x10000000 or e == 0x7FF or (xy_z - xy == z and xy_z - z == xy)) {
        return @floatCast(f32, xy_z);
    } else {
        // TODO: Handle inexact case with double-rounding
        return @floatCast(f32, xy_z);
    }
}

// NOTE: Upstream fma.c has been rewritten completely to raise fp exceptions more accurately.
fn fma64(x: f64, y: f64, z: f64) f64 {
    if (!math.isFinite(x) or !math.isFinite(y)) {
        return x * y + z;
    }
    if (!math.isFinite(z)) {
        return z;
    }
    if (x == 0.0 or y == 0.0) {
        return x * y + z;
    }
    if (z == 0.0) {
        return x * y;
    }

    const x1 = math.frexp(x);
    var ex = x1.exponent;
    var xs = x1.significand;
    const x2 = math.frexp(y);
    var ey = x2.exponent;
    var ys = x2.significand;
    const x3 = math.frexp(z);
    var ez = x3.exponent;
    var zs = x3.significand;

    var spread = ex + ey - ez;
    if (spread <= 53 * 2) {
        zs = math.scalbn(zs, -spread);
    } else {
        zs = math.copysign(f64, math.f64_min, zs);
    }

    const xy = dd_mul(xs, ys);
    const r = dd_add(xy.hi, zs);
    spread = ex + ey;

    if (r.hi == 0.0) {
        return xy.hi + zs + math.scalbn(xy.lo, spread);
    }

    const adj = add_adjusted(r.lo, xy.lo);
    if (spread + math.ilogb(r.hi) > -1023) {
        return math.scalbn(r.hi + adj, spread);
    } else {
        return add_and_denorm(r.hi, adj, spread);
    }
}

const dd = struct {
    hi: f64,
    lo: f64,
};

fn dd_add(a: f64, b: f64) dd {
    var ret: dd = undefined;
    ret.hi = a + b;
    const s = ret.hi - a;
    ret.lo = (a - (ret.hi - s)) + (b - s);
    return ret;
}

fn dd_mul(a: f64, b: f64) dd {
    var ret: dd = undefined;
    const split: f64 = 0x1.0p27 + 1.0;

    var p = a * split;
    var ha = a - p;
    ha += p;
    var la = a - ha;

    p = b * split;
    var hb = b - p;
    hb += p;
    var lb = b - hb;

    p = ha * hb;
    var q = ha * lb + la * hb;

    ret.hi = p + q;
    ret.lo = p - ret.hi + q + la * lb;
    return ret;
}

fn add_adjusted(a: f64, b: f64) f64 {
    var sum = dd_add(a, b);
    if (sum.lo != 0) {
        var uhii = @bitCast(u64, sum.hi);
        if (uhii & 1 == 0) {
            // hibits += copysign(1.0, sum.hi, sum.lo)
            const uloi = @bitCast(u64, sum.lo);
            uhii += 1 - ((uhii ^ uloi) >> 62);
            sum.hi = @bitCast(f64, uhii);
        }
    }
    return sum.hi;
}

fn add_and_denorm(a: f64, b: f64, scale: i32) f64 {
    var sum = dd_add(a, b);
    if (sum.lo != 0) {
        var uhii = @bitCast(u64, sum.hi);
        const bits_lost = -@intCast(i32, (uhii >> 52) & 0x7FF) - scale + 1;
        if ((bits_lost != 1) == (uhii & 1 != 0)) {
            const uloi = @bitCast(u64, sum.lo);
            uhii += 1 - (((uhii ^ uloi) >> 62) & 2);
            sum.hi = @bitCast(f64, uhii);
        }
    }
    return math.scalbn(sum.hi, scale);
}

test "math.fma" {
    expect(fma(f32, 0.0, 1.0, 1.0) == fma32(0.0, 1.0, 1.0));
    expect(fma(f64, 0.0, 1.0, 1.0) == fma64(0.0, 1.0, 1.0));
}

test "math.fma32" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f32, fma32(0.0, 5.0, 9.124), 9.124, epsilon));
    expect(math.approxEqAbs(f32, fma32(0.2, 5.0, 9.124), 10.124, epsilon));
    expect(math.approxEqAbs(f32, fma32(0.8923, 5.0, 9.124), 13.5855, epsilon));
    expect(math.approxEqAbs(f32, fma32(1.5, 5.0, 9.124), 16.624, epsilon));
    expect(math.approxEqAbs(f32, fma32(37.45, 5.0, 9.124), 196.374004, epsilon));
    expect(math.approxEqAbs(f32, fma32(89.123, 5.0, 9.124), 454.739005, epsilon));
    expect(math.approxEqAbs(f32, fma32(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

test "math.fma64" {
    const epsilon = 0.000001;

    expect(math.approxEqAbs(f64, fma64(0.0, 5.0, 9.124), 9.124, epsilon));
    expect(math.approxEqAbs(f64, fma64(0.2, 5.0, 9.124), 10.124, epsilon));
    expect(math.approxEqAbs(f64, fma64(0.8923, 5.0, 9.124), 13.5855, epsilon));
    expect(math.approxEqAbs(f64, fma64(1.5, 5.0, 9.124), 16.624, epsilon));
    expect(math.approxEqAbs(f64, fma64(37.45, 5.0, 9.124), 196.374, epsilon));
    expect(math.approxEqAbs(f64, fma64(89.123, 5.0, 9.124), 454.739, epsilon));
    expect(math.approxEqAbs(f64, fma64(123123.234375, 5.0, 9.124), 615625.295875, epsilon));
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/atan2f.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/atan2.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the arc-tangent of y/x.
///
/// Special Cases:
///  - atan2(y, nan)     = nan
///  - atan2(nan, x)     = nan
///  - atan2(+0, x>=0)   = +0
///  - atan2(-0, x>=0)   = -0
///  - atan2(+0, x<=-0)  = +pi
///  - atan2(-0, x<=-0)  = -pi
///  - atan2(y>0, 0)     = +pi/2
///  - atan2(y<0, 0)     = -pi/2
///  - atan2(+inf, +inf) = +pi/4
///  - atan2(-inf, +inf) = -pi/4
///  - atan2(+inf, -inf) = 3pi/4
///  - atan2(-inf, -inf) = -3pi/4
///  - atan2(y, +inf)    = 0
///  - atan2(y>0, -inf)  = +pi
///  - atan2(y<0, -inf)  = -pi
///  - atan2(+inf, x)    = +pi/2
///  - atan2(-inf, x)    = -pi/2
pub fn atan2(comptime T: type, y: T, x: T) T {
    return switch (T) {
        f32 => atan2_32(y, x),
        f64 => atan2_64(y, x),
        else => @compileError("atan2 not implemented for " ++ @typeName(T)),
    };
}

fn atan2_32(y: f32, x: f32) f32 {
    const pi: f32 = 3.1415927410e+00;
    const pi_lo: f32 = -8.7422776573e-08;

    if (math.isNan(x) or math.isNan(y)) {
        return x + y;
    }

    var ix = @bitCast(u32, x);
    var iy = @bitCast(u32, y);

    // x = 1.0
    if (ix == 0x3F800000) {
        return math.atan(y);
    }

    // 2 * sign(x) + sign(y)
    const m = ((iy >> 31) & 1) | ((ix >> 30) & 2);
    ix &= 0x7FFFFFFF;
    iy &= 0x7FFFFFFF;

    if (iy == 0) {
        switch (m) {
            0, 1 => return y, // atan(+-0, +...)
            2 => return pi, // atan(+0, -...)
            3 => return -pi, // atan(-0, -...)
            else => unreachable,
        }
    }

    if (ix == 0) {
        if (m & 1 != 0) {
            return -pi / 2;
        } else {
            return pi / 2;
        }
    }

    if (ix == 0x7F800000) {
        if (iy == 0x7F800000) {
            switch (m) {
                0 => return pi / 4, // atan(+inf, +inf)
                1 => return -pi / 4, // atan(-inf, +inf)
                2 => return 3 * pi / 4, // atan(+inf, -inf)
                3 => return -3 * pi / 4, // atan(-inf, -inf)
                else => unreachable,
            }
        } else {
            switch (m) {
                0 => return 0.0, // atan(+..., +inf)
                1 => return -0.0, // atan(-..., +inf)
                2 => return pi, // atan(+..., -inf)
                3 => return -pi, // atan(-...f, -inf)
                else => unreachable,
            }
        }
    }

    // |y / x| > 0x1p26
    if (ix + (26 << 23) < iy or iy == 0x7F800000) {
        if (m & 1 != 0) {
            return -pi / 2;
        } else {
            return pi / 2;
        }
    }

    // z = atan(|y / x|) with correct underflow
    var z = z: {
        if ((m & 2) != 0 and iy + (26 << 23) < ix) {
            break :z 0.0;
        } else {
            break :z math.atan(math.fabs(y / x));
        }
    };

    switch (m) {
        0 => return z, // atan(+, +)
        1 => return -z, // atan(-, +)
        2 => return pi - (z - pi_lo), // atan(+, -)
        3 => return (z - pi_lo) - pi, // atan(-, -)
        else => unreachable,
    }
}

fn atan2_64(y: f64, x: f64) f64 {
    const pi: f64 = 3.1415926535897931160E+00;
    const pi_lo: f64 = 1.2246467991473531772E-16;

    if (math.isNan(x) or math.isNan(y)) {
        return x + y;
    }

    var ux = @bitCast(u64, x);
    var ix = @intCast(u32, ux >> 32);
    var lx = @intCast(u32, ux & 0xFFFFFFFF);

    var uy = @bitCast(u64, y);
    var iy = @intCast(u32, uy >> 32);
    var ly = @intCast(u32, uy & 0xFFFFFFFF);

    // x = 1.0
    if ((ix -% 0x3FF00000) | lx == 0) {
        return math.atan(y);
    }

    // 2 * sign(x) + sign(y)
    const m = ((iy >> 31) & 1) | ((ix >> 30) & 2);
    ix &= 0x7FFFFFFF;
    iy &= 0x7FFFFFFF;

    if (iy | ly == 0) {
        switch (m) {
            0, 1 => return y, // atan(+-0, +...)
            2 => return pi, // atan(+0, -...)
            3 => return -pi, // atan(-0, -...)
            else => unreachable,
        }
    }

    if (ix | lx == 0) {
        if (m & 1 != 0) {
            return -pi / 2;
        } else {
            return pi / 2;
        }
    }

    if (ix == 0x7FF00000) {
        if (iy == 0x7FF00000) {
            switch (m) {
                0 => return pi / 4, // atan(+inf, +inf)
                1 => return -pi / 4, // atan(-inf, +inf)
                2 => return 3 * pi / 4, // atan(+inf, -inf)
                3 => return -3 * pi / 4, // atan(-inf, -inf)
                else => unreachable,
            }
        } else {
            switch (m) {
                0 => return 0.0, // atan(+..., +inf)
                1 => return -0.0, // atan(-..., +inf)
                2 => return pi, // atan(+..., -inf)
                3 => return -pi, // atan(-...f, -inf)
                else => unreachable,
            }
        }
    }

    // |y / x| > 0x1p64
    if (ix +% (64 << 20) < iy or iy == 0x7FF00000) {
        if (m & 1 != 0) {
            return -pi / 2;
        } else {
            return pi / 2;
        }
    }

    // z = atan(|y / x|) with correct underflow
    var z = z: {
        if ((m & 2) != 0 and iy +% (64 << 20) < ix) {
            break :z 0.0;
        } else {
            break :z math.atan(math.fabs(y / x));
        }
    };

    switch (m) {
        0 => return z, // atan(+, +)
        1 => return -z, // atan(-, +)
        2 => return pi - (z - pi_lo), // atan(+, -)
        3 => return (z - pi_lo) - pi, // atan(-, -)
        else => unreachable,
    }
}

test "math.atan2" {
    expect(atan2(f32, 0.2, 0.21) == atan2_32(0.2, 0.21));
    expect(atan2(f64, 0.2, 0.21) == atan2_64(0.2, 0.21));
}

test "math.atan2_32" {
    const epsilon = 0.000001;

    expect(math.approxEq(f32, atan2_32(0.0, 0.0), 0.0, epsilon));
    expect(math.approxEq(f32, atan2_32(0.2, 0.2), 0.785398, epsilon));
    expect(math.approxEq(f32, atan2_32(-0.2, 0.2), -0.785398, epsilon));
    expect(math.approxEq(f32, atan2_32(0.2, -0.2), 2.356194, epsilon));
    expect(math.approxEq(f32, atan2_32(-0.2, -0.2), -2.356194, epsilon));
    expect(math.approxEq(f32, atan2_32(0.34, -0.4), 2.437099, epsilon));
    expect(math.approxEq(f32, atan2_32(0.34, 1.243), 0.267001, epsilon));
}

test "math.atan2_64" {
    const epsilon = 0.000001;

    expect(math.approxEq(f64, atan2_64(0.0, 0.0), 0.0, epsilon));
    expect(math.approxEq(f64, atan2_64(0.2, 0.2), 0.785398, epsilon));
    expect(math.approxEq(f64, atan2_64(-0.2, 0.2), -0.785398, epsilon));
    expect(math.approxEq(f64, atan2_64(0.2, -0.2), 2.356194, epsilon));
    expect(math.approxEq(f64, atan2_64(-0.2, -0.2), -2.356194, epsilon));
    expect(math.approxEq(f64, atan2_64(0.34, -0.4), 2.437099, epsilon));
    expect(math.approxEq(f64, atan2_64(0.34, 1.243), 0.267001, epsilon));
}

test "math.atan2_32.special" {
    const epsilon = 0.000001;

    expect(math.isNan(atan2_32(1.0, math.nan(f32))));
    expect(math.isNan(atan2_32(math.nan(f32), 1.0)));
    expect(atan2_32(0.0, 5.0) == 0.0);
    expect(atan2_32(-0.0, 5.0) == -0.0);
    expect(math.approxEq(f32, atan2_32(0.0, -5.0), math.pi, epsilon));
    //expect(math.approxEq(f32, atan2_32(-0.0, -5.0), -math.pi, epsilon)); TODO support negative zero?
    expect(math.approxEq(f32, atan2_32(1.0, 0.0), math.pi / 2.0, epsilon));
    expect(math.approxEq(f32, atan2_32(1.0, -0.0), math.pi / 2.0, epsilon));
    expect(math.approxEq(f32, atan2_32(-1.0, 0.0), -math.pi / 2.0, epsilon));
    expect(math.approxEq(f32, atan2_32(-1.0, -0.0), -math.pi / 2.0, epsilon));
    expect(math.approxEq(f32, atan2_32(math.inf(f32), math.inf(f32)), math.pi / 4.0, epsilon));
    expect(math.approxEq(f32, atan2_32(-math.inf(f32), math.inf(f32)), -math.pi / 4.0, epsilon));
    expect(math.approxEq(f32, atan2_32(math.inf(f32), -math.inf(f32)), 3.0 * math.pi / 4.0, epsilon));
    expect(math.approxEq(f32, atan2_32(-math.inf(f32), -math.inf(f32)), -3.0 * math.pi / 4.0, epsilon));
    expect(atan2_32(1.0, math.inf(f32)) == 0.0);
    expect(math.approxEq(f32, atan2_32(1.0, -math.inf(f32)), math.pi, epsilon));
    expect(math.approxEq(f32, atan2_32(-1.0, -math.inf(f32)), -math.pi, epsilon));
    expect(math.approxEq(f32, atan2_32(math.inf(f32), 1.0), math.pi / 2.0, epsilon));
    expect(math.approxEq(f32, atan2_32(-math.inf(f32), 1.0), -math.pi / 2.0, epsilon));
}

test "math.atan2_64.special" {
    const epsilon = 0.000001;

    expect(math.isNan(atan2_64(1.0, math.nan(f64))));
    expect(math.isNan(atan2_64(math.nan(f64), 1.0)));
    expect(atan2_64(0.0, 5.0) == 0.0);
    expect(atan2_64(-0.0, 5.0) == -0.0);
    expect(math.approxEq(f64, atan2_64(0.0, -5.0), math.pi, epsilon));
    //expect(math.approxEq(f64, atan2_64(-0.0, -5.0), -math.pi, epsilon)); TODO support negative zero?
    expect(math.approxEq(f64, atan2_64(1.0, 0.0), math.pi / 2.0, epsilon));
    expect(math.approxEq(f64, atan2_64(1.0, -0.0), math.pi / 2.0, epsilon));
    expect(math.approxEq(f64, atan2_64(-1.0, 0.0), -math.pi / 2.0, epsilon));
    expect(math.approxEq(f64, atan2_64(-1.0, -0.0), -math.pi / 2.0, epsilon));
    expect(math.approxEq(f64, atan2_64(math.inf(f64), math.inf(f64)), math.pi / 4.0, epsilon));
    expect(math.approxEq(f64, atan2_64(-math.inf(f64), math.inf(f64)), -math.pi / 4.0, epsilon));
    expect(math.approxEq(f64, atan2_64(math.inf(f64), -math.inf(f64)), 3.0 * math.pi / 4.0, epsilon));
    expect(math.approxEq(f64, atan2_64(-math.inf(f64), -math.inf(f64)), -3.0 * math.pi / 4.0, epsilon));
    expect(atan2_64(1.0, math.inf(f64)) == 0.0);
    expect(math.approxEq(f64, atan2_64(1.0, -math.inf(f64)), math.pi, epsilon));
    expect(math.approxEq(f64, atan2_64(-1.0, -math.inf(f64)), -math.pi, epsilon));
    expect(math.approxEq(f64, atan2_64(math.inf(f64), 1.0), math.pi / 2.0, epsilon));
    expect(math.approxEq(f64, atan2_64(-math.inf(f64), 1.0), -math.pi / 2.0, epsilon));
}

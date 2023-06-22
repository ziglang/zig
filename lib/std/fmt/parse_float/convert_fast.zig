//! Representation of a float as the significant digits and exponent.
//! The fast path algorithm using machine-sized integers and floats.
//!
//! This only works if both the mantissa and the exponent can be exactly
//! represented as a machine float, since IEE-754 guarantees no rounding
//! will occur.
//!
//! There is an exception: disguised fast-path cases, where we can shift
//! powers-of-10 from the exponent to the significant digits.

const std = @import("std");
const math = std.math;
const common = @import("common.zig");
const FloatInfo = @import("FloatInfo.zig");
const Number = common.Number;
const floatFromU64 = common.floatFromU64;

fn isFastPath(comptime T: type, n: Number(T)) bool {
    const info = FloatInfo.from(T);

    return info.min_exponent_fast_path <= n.exponent and
        n.exponent <= info.max_exponent_fast_path_disguised and
        n.mantissa <= info.max_mantissa_fast_path and
        !n.many_digits;
}

// upper bound for tables is floor(mantissaDigits(T) / log2(5))
// for f64 this is floor(53 / log2(5)) = 22.
//
// Must have max_disguised_fast_path - max_exponent_fast_path entries. (82 - 48 = 34 for f128)
fn fastPow10(comptime T: type, i: usize) T {
    return switch (T) {
        f16 => ([8]f16{
            1e0, 1e1, 1e2, 1e3, 1e4, 0, 0, 0,
        })[i & 7],

        f32 => ([16]f32{
            1e0, 1e1, 1e2,  1e3, 1e4, 1e5, 1e6, 1e7,
            1e8, 1e9, 1e10, 0,   0,   0,   0,   0,
        })[i & 15],

        f64 => ([32]f64{
            1e0,  1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7,
            1e8,  1e9,  1e10, 1e11, 1e12, 1e13, 1e14, 1e15,
            1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22, 0,
            0,    0,    0,    0,    0,    0,    0,    0,
        })[i & 31],

        f128 => ([64]f128{
            1e0,  1e1,  1e2,  1e3,  1e4,  1e5,  1e6,  1e7,
            1e8,  1e9,  1e10, 1e11, 1e12, 1e13, 1e14, 1e15,
            1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22, 1e23,
            1e24, 1e25, 1e26, 1e27, 1e28, 1e29, 1e30, 1e31,
            1e32, 1e33, 1e34, 1e35, 1e36, 1e37, 1e38, 1e39,
            1e40, 1e41, 1e42, 1e43, 1e44, 1e45, 1e46, 1e47,
            1e48, 0,    0,    0,    0,    0,    0,    0,
            0,    0,    0,    0,    0,    0,    0,    0,
        })[i & 63],

        else => unreachable,
    };
}

fn fastIntPow10(comptime T: type, i: usize) T {
    return switch (T) {
        u64 => ([16]u64{
            1,             10,             100,             1000,
            10000,         100000,         1000000,         10000000,
            100000000,     1000000000,     10000000000,     100000000000,
            1000000000000, 10000000000000, 100000000000000, 1000000000000000,
        })[i],

        u128 => ([35]u128{
            1,                                   10,
            100,                                 1000,
            10000,                               100000,
            1000000,                             10000000,
            100000000,                           1000000000,
            10000000000,                         100000000000,
            1000000000000,                       10000000000000,
            100000000000000,                     1000000000000000,
            10000000000000000,                   100000000000000000,
            1000000000000000000,                 10000000000000000000,
            100000000000000000000,               1000000000000000000000,
            10000000000000000000000,             100000000000000000000000,
            1000000000000000000000000,           10000000000000000000000000,
            100000000000000000000000000,         1000000000000000000000000000,
            10000000000000000000000000000,       100000000000000000000000000000,
            1000000000000000000000000000000,     10000000000000000000000000000000,
            100000000000000000000000000000000,   1000000000000000000000000000000000,
            10000000000000000000000000000000000,
        })[i],

        else => unreachable,
    };
}

pub fn convertFast(comptime T: type, n: Number(T)) ?T {
    const MantissaT = common.mantissaType(T);

    if (!isFastPath(T, n)) {
        return null;
    }

    // TODO: x86 (no SSE/SSE2) requires x87 FPU to be setup correctly with fldcw
    const info = FloatInfo.from(T);

    var value: T = 0;
    if (n.exponent <= info.max_exponent_fast_path) {
        // normal fast path
        value = @as(T, @floatFromInt(n.mantissa));
        value = if (n.exponent < 0)
            value / fastPow10(T, @as(usize, @intCast(-n.exponent)))
        else
            value * fastPow10(T, @as(usize, @intCast(n.exponent)));
    } else {
        // disguised fast path
        const shift = n.exponent - info.max_exponent_fast_path;
        const mantissa = math.mul(MantissaT, n.mantissa, fastIntPow10(MantissaT, @as(usize, @intCast(shift)))) catch return null;
        if (mantissa > info.max_mantissa_fast_path) {
            return null;
        }
        value = @as(T, @floatFromInt(mantissa)) * fastPow10(T, info.max_exponent_fast_path);
    }

    if (n.negative) {
        value = -value;
    }
    return value;
}

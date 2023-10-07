const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const math = std.math;
const common = @import("common.zig");

pub const panic = common.panic;

comptime {
    @export(__sqrth, .{ .name = "__sqrth", .linkage = common.linkage, .visibility = common.visibility });
    @export(sqrtf, .{ .name = "sqrtf", .linkage = common.linkage, .visibility = common.visibility });
    @export(sqrt, .{ .name = "sqrt", .linkage = common.linkage, .visibility = common.visibility });
    @export(__sqrtx, .{ .name = "__sqrtx", .linkage = common.linkage, .visibility = common.visibility });
    if (common.want_ppc_abi) {
        @export(sqrtq, .{ .name = "sqrtf128", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(sqrtq, .{ .name = "sqrtq", .linkage = common.linkage, .visibility = common.visibility });
    @export(sqrtl, .{ .name = "sqrtl", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __sqrth(x: f16) callconv(.C) f16 {
    // TODO: more efficient implementation
    return @floatCast(sqrtf(x));
}

pub fn sqrtf(x: f32) callconv(.C) f32 {
    const tiny: f32 = 1.0e-30;
    const sign: i32 = @bitCast(@as(u32, 0x80000000));
    var ix: i32 = @bitCast(x);

    if ((ix & 0x7F800000) == 0x7F800000) {
        return x * x + x; // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = nan
    }

    // zero
    if (ix <= 0) {
        if (ix & ~sign == 0) {
            return x; // sqrt (+-0) = +-0
        }
        if (ix < 0) {
            return math.nan(f32);
        }
    }

    // normalize
    var m = ix >> 23;
    if (m == 0) {
        // subnormal
        var i: i32 = 0;
        while (ix & 0x00800000 == 0) : (i += 1) {
            ix <<= 1;
        }
        m -= i - 1;
    }

    m -= 127; // unbias exponent
    ix = (ix & 0x007FFFFF) | 0x00800000;

    if (m & 1 != 0) { // odd m, double x to even
        ix += ix;
    }

    m >>= 1; // m = [m / 2]

    // sqrt(x) bit by bit
    ix += ix;
    var q: i32 = 0; // q = sqrt(x)
    var s: i32 = 0;
    var r: i32 = 0x01000000; // r = moving bit right -> left

    while (r != 0) {
        const t = s + r;
        if (t <= ix) {
            s = t + r;
            ix -= t;
            q += r;
        }
        ix += ix;
        r >>= 1;
    }

    // floating add to find rounding direction
    if (ix != 0) {
        var z = 1.0 - tiny; // inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (z > 1.0) {
                q += 2;
            } else {
                if (q & 1 != 0) {
                    q += 1;
                }
            }
        }
    }

    ix = (q >> 1) + 0x3f000000;
    ix += m << 23;
    return @bitCast(ix);
}

/// NOTE: The original code is full of implicit signed -> unsigned assumptions and u32 wraparound
/// behaviour. Most intermediate i32 values are changed to u32 where appropriate but there are
/// potentially some edge cases remaining that are not handled in the same way.
pub fn sqrt(x: f64) callconv(.C) f64 {
    const tiny: f64 = 1.0e-300;
    const sign: u32 = 0x80000000;
    const u: u64 = @bitCast(x);

    var ix0: u32 = @intCast(u >> 32);
    var ix1: u32 = @intCast(u & 0xFFFFFFFF);

    // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = nan
    if (ix0 & 0x7FF00000 == 0x7FF00000) {
        return x * x + x;
    }

    // sqrt(+-0) = +-0
    if (x == 0.0) {
        return x;
    }
    // sqrt(-ve) = nan
    if (ix0 & sign != 0) {
        return math.nan(f64);
    }

    // normalize x
    var m: i32 = @intCast(ix0 >> 20);
    if (m == 0) {
        // subnormal
        while (ix0 == 0) {
            m -= 21;
            ix0 |= ix1 >> 11;
            ix1 <<= 21;
        }

        // subnormal
        var i: u32 = 0;
        while (ix0 & 0x00100000 == 0) : (i += 1) {
            ix0 <<= 1;
        }
        m -= @as(i32, @intCast(i)) - 1;
        ix0 |= ix1 >> @intCast(32 - i);
        ix1 <<= @intCast(i);
    }

    // unbias exponent
    m -= 1023;
    ix0 = (ix0 & 0x000FFFFF) | 0x00100000;
    if (m & 1 != 0) {
        ix0 += ix0 + (ix1 >> 31);
        ix1 = ix1 +% ix1;
    }
    m >>= 1;

    // sqrt(x) bit by bit
    ix0 += ix0 + (ix1 >> 31);
    ix1 = ix1 +% ix1;

    var q: u32 = 0;
    var q1: u32 = 0;
    var s0: u32 = 0;
    var s1: u32 = 0;
    var r: u32 = 0x00200000;
    var t: u32 = undefined;
    var t1: u32 = undefined;

    while (r != 0) {
        t = s0 +% r;
        if (t <= ix0) {
            s0 = t + r;
            ix0 -= t;
            q += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    r = sign;
    while (r != 0) {
        t1 = s1 +% r;
        t = s0;
        if (t < ix0 or (t == ix0 and t1 <= ix1)) {
            s1 = t1 +% r;
            if (t1 & sign == sign and s1 & sign == 0) {
                s0 += 1;
            }
            ix0 -= t;
            if (ix1 < t1) {
                ix0 -= 1;
            }
            ix1 = ix1 -% t1;
            q1 += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    // rounding direction
    if (ix0 | ix1 != 0) {
        var z = 1.0 - tiny; // raise inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (q1 == 0xFFFFFFFF) {
                q1 = 0;
                q += 1;
            } else if (z > 1.0) {
                if (q1 == 0xFFFFFFFE) {
                    q += 1;
                }
                q1 += 2;
            } else {
                q1 += q1 & 1;
            }
        }
    }

    ix0 = (q >> 1) + 0x3FE00000;
    ix1 = q1 >> 1;
    if (q & 1 != 0) {
        ix1 |= 0x80000000;
    }

    // NOTE: musl here appears to rely on signed twos-complement wraparound. +% has the same
    // behaviour at least.
    var iix0: i32 = @intCast(ix0);
    iix0 = iix0 +% (m << 20);

    const uz = (@as(u64, @intCast(iix0)) << 32) | ix1;
    return @bitCast(uz);
}

pub fn __sqrtx(x: f80) callconv(.C) f80 {
    // TODO: more efficient implementation
    return @floatCast(sqrtq(x));
}

pub fn sqrtq(x: f128) callconv(.C) f128 {
    // TODO: more correct implementation
    return sqrt(@floatCast(x));
}

pub fn sqrtl(x: c_longdouble) callconv(.C) c_longdouble {
    switch (@typeInfo(c_longdouble).Float.bits) {
        16 => return __sqrth(x),
        32 => return sqrtf(x),
        64 => return sqrt(x),
        80 => return __sqrtx(x),
        128 => return sqrtq(x),
        else => @compileError("unreachable"),
    }
}

test "sqrtf" {
    const V = [_]f32{
        0.0,
        4.089288054930154,
        7.538757127071935,
        8.97780793672623,
        5.304443821913729,
        5.682408965311888,
        0.5846878579110049,
        3.650338664297043,
        0.3178091951800732,
        7.1505232436382835,
        3.6589165881946464,
    };

    // Note that @sqrt will either generate the sqrt opcode (if supported by the
    // target ISA) or a call to `sqrtf` otherwise.
    for (V) |val|
        try std.testing.expectEqual(@sqrt(val), sqrtf(val));
}

test "sqrtf special" {
    try std.testing.expect(math.isPositiveInf(sqrtf(math.inf(f32))));
    try std.testing.expect(sqrtf(0.0) == 0.0);
    try std.testing.expect(sqrtf(-0.0) == -0.0);
    try std.testing.expect(math.isNan(sqrtf(-1.0)));
    try std.testing.expect(math.isNan(sqrtf(math.nan(f32))));
}

test "sqrt" {
    const V = [_]f64{
        0.0,
        4.089288054930154,
        7.538757127071935,
        8.97780793672623,
        5.304443821913729,
        5.682408965311888,
        0.5846878579110049,
        3.650338664297043,
        0.3178091951800732,
        7.1505232436382835,
        3.6589165881946464,
    };

    // Note that @sqrt will either generate the sqrt opcode (if supported by the
    // target ISA) or a call to `sqrtf` otherwise.
    for (V) |val|
        try std.testing.expectEqual(@sqrt(val), sqrt(val));
}

test "sqrt special" {
    try std.testing.expect(math.isPositiveInf(sqrt(math.inf(f64))));
    try std.testing.expect(sqrt(0.0) == 0.0);
    try std.testing.expect(sqrt(-0.0) == -0.0);
    try std.testing.expect(math.isNan(sqrt(-1.0)));
    try std.testing.expect(math.isNan(sqrt(math.nan(f64))));
}

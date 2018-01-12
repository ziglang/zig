// Special Cases:
//
// - sqrt(+inf)  = +inf
// - sqrt(+-0)   = +-0
// - sqrt(x)     = nan if x < 0
// - sqrt(nan)   = nan

const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;
const builtin = @import("builtin");
const TypeId = builtin.TypeId;

pub fn sqrt(x: var) -> (if (@typeId(@typeOf(x)) == TypeId.Int) @IntType(false, @typeOf(x).bit_count / 2) else @typeOf(x)) {
    const T = @typeOf(x);
    switch (@typeId(T)) {
        TypeId.FloatLiteral => {
            return T(sqrt64(x));
        },
        TypeId.Float => {
            switch (T) {
                f32 => {
                    switch (builtin.arch) {
                        builtin.Arch.x86_64 => return @import("x86_64/sqrt.zig").sqrt32(x),
                        else => return sqrt32(x),
                    }
                },
                f64 => {
                    switch (builtin.arch) {
                        builtin.Arch.x86_64 => return @import("x86_64/sqrt.zig").sqrt64(x),
                        else => return sqrt64(x),
                    }
                },
                else => @compileError("sqrt not implemented for " ++ @typeName(T)),
            }
        },
        TypeId.IntLiteral => comptime {
            if (x > @maxValue(u128)) {
                @compileError("sqrt not implemented for comptime_int greater than 128 bits");
            }
            if (x < 0) {
                @compileError("sqrt on negative number");
            }
            return T(sqrt_int(u128, x));
        },
        TypeId.Int => {
            return sqrt_int(T, x);
        },
        else => @compileError("sqrt not implemented for " ++ @typeName(T)),
    }
}

fn sqrt32(x: f32) -> f32 {
    const tiny: f32 = 1.0e-30;
    const sign: i32 = @bitCast(i32, u32(0x80000000));
    var ix: i32 = @bitCast(i32, x);

    if ((ix & 0x7F800000) == 0x7F800000) {
        return x * x + x;   // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = snan
    }

    // zero
    if (ix <= 0) {
        if (ix & ~sign == 0) {
            return x;       // sqrt (+-0) = +-0
        }
        if (ix < 0) {
            return math.snan(f32);
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

    m -= 127;               // unbias exponent
    ix = (ix & 0x007FFFFF) | 0x00800000;

    if (m & 1 != 0) {       // odd m, double x to even
        ix += ix;
    }

    m >>= 1;                // m = [m / 2]

    // sqrt(x) bit by bit
    ix += ix;
    var q: i32 = 0;              // q = sqrt(x)
    var s: i32 = 0;
    var r: i32 = 0x01000000;     // r = moving bit right -> left

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
        var z = 1.0 - tiny;     // inexact
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
    return @bitCast(f32, ix);
}

// NOTE: The original code is full of implicit signed -> unsigned assumptions and u32 wraparound
// behaviour. Most intermediate i32 values are changed to u32 where appropriate but there are
// potentially some edge cases remaining that are not handled in the same way.
fn sqrt64(x: f64) -> f64 {
    const tiny: f64 = 1.0e-300;
    const sign: u32 = 0x80000000;
    const u = @bitCast(u64, x);

    var ix0 = u32(u >> 32);
    var ix1 = u32(u & 0xFFFFFFFF);

    // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = nan
    if (ix0 & 0x7FF00000 == 0x7FF00000) {
        return x * x + x;
    }

    // sqrt(+-0) = +-0
    if (x == 0.0) {
        return x;
    }
    // sqrt(-ve) = snan
    if (ix0 & sign != 0) {
        return math.snan(f64);
    }

    // normalize x
    var m = i32(ix0 >> 20);
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
        m -= i32(i) - 1;
        ix0 |= ix1 >> u5(32 - i);
        ix1 <<= u5(i);
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
        t = s1 +% r;
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
        var z = 1.0 - tiny;   // raise inexact
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
    var iix0 = i32(ix0);
    iix0 = iix0 +% (m << 20);

    const uz = (u64(iix0) << 32) | ix1;
    return @bitCast(f64, uz);
}

test "math.sqrt" {
    assert(sqrt(f32(0.0)) == sqrt32(0.0));
    assert(sqrt(f64(0.0)) == sqrt64(0.0));
}

test "math.sqrt32" {
    const epsilon = 0.000001;

    assert(sqrt32(0.0) == 0.0);
    assert(math.approxEq(f32, sqrt32(2.0), 1.414214, epsilon));
    assert(math.approxEq(f32, sqrt32(3.6), 1.897367, epsilon));
    assert(sqrt32(4.0) == 2.0);
    assert(math.approxEq(f32, sqrt32(7.539840), 2.745877, epsilon));
    assert(math.approxEq(f32, sqrt32(19.230934), 4.385309, epsilon));
    assert(sqrt32(64.0) == 8.0);
    assert(math.approxEq(f32, sqrt32(64.1), 8.006248, epsilon));
    assert(math.approxEq(f32, sqrt32(8942.230469), 94.563370, epsilon));
}

test "math.sqrt64" {
    const epsilon = 0.000001;

    assert(sqrt64(0.0) == 0.0);
    assert(math.approxEq(f64, sqrt64(2.0), 1.414214, epsilon));
    assert(math.approxEq(f64, sqrt64(3.6), 1.897367, epsilon));
    assert(sqrt64(4.0) == 2.0);
    assert(math.approxEq(f64, sqrt64(7.539840), 2.745877, epsilon));
    assert(math.approxEq(f64, sqrt64(19.230934), 4.385309, epsilon));
    assert(sqrt64(64.0) == 8.0);
    assert(math.approxEq(f64, sqrt64(64.1), 8.006248, epsilon));
    assert(math.approxEq(f64, sqrt64(8942.230469), 94.563367, epsilon));
}

test "math.sqrt32.special" {
    assert(math.isPositiveInf(sqrt32(math.inf(f32))));
    assert(sqrt32(0.0) == 0.0);
    assert(sqrt32(-0.0) == -0.0);
    assert(math.isNan(sqrt32(-1.0)));
    assert(math.isNan(sqrt32(math.nan(f32))));
}

test "math.sqrt64.special" {
    assert(math.isPositiveInf(sqrt64(math.inf(f64))));
    assert(sqrt64(0.0) == 0.0);
    assert(sqrt64(-0.0) == -0.0);
    assert(math.isNan(sqrt64(-1.0)));
    assert(math.isNan(sqrt64(math.nan(f64))));
}

fn sqrt_int(comptime T: type, value: T) -> @IntType(false, T.bit_count / 2) {
    var op = value;
    var res: T = 0;
    var one: T = 1 << (T.bit_count - 2);

    // "one" starts at the highest power of four <= than the argument.
    while (one > op) {
        one >>= 2;
    }

    while (one != 0) {
        if (op >= res + one) {
            op -= res + one;
            res += 2 * one;
        }
        res >>= 1;
        one >>= 2;
    }

    const ResultType = @IntType(false, T.bit_count / 2);
    return ResultType(res);
}

test "math.sqrt_int" {
    assert(sqrt_int(u32, 3) == 1);
    assert(sqrt_int(u32, 4) == 2);
    assert(sqrt_int(u32, 5) == 2);
    assert(sqrt_int(u32, 8) == 2);
    assert(sqrt_int(u32, 9) == 3);
    assert(sqrt_int(u32, 10) == 3);
}

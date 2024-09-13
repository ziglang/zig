// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/tgamma.c

const builtin = @import("builtin");
const std = @import("../std.zig");

/// Returns the gamma function of x,
/// gamma(x) = factorial(x - 1) for integer x.
///
/// Special Cases:
///  - gamma(+-nan) = nan
///  - gamma(-inf)  = nan
///  - gamma(n)     = nan for negative integers
///  - gamma(-0.0)  = -inf
///  - gamma(+0.0)  = +inf
///  - gamma(+inf)  = +inf
pub fn gamma(comptime T: type, x: T) T {
    if (T != f32 and T != f64) {
        @compileError("gamma not implemented for " ++ @typeName(T));
    }
    // common integer case first
    if (x == @trunc(x)) {
        // gamma(-inf) = nan
        // gamma(n)    = nan for negative integers
        if (x < 0) {
            return std.math.nan(T);
        }
        // gamma(-0.0) = -inf
        // gamma(+0.0) = +inf
        if (x == 0) {
            return 1 / x;
        }
        if (x < integer_result_table.len) {
            const i = @as(u8, @intFromFloat(x));
            return @floatCast(integer_result_table[i]);
        }
    }
    // below this, result underflows, but has a sign
    // negative for (-1,  0)
    // positive for (-2, -1)
    // negative for (-3, -2)
    // ...
    const lower_bound = if (T == f64) -184 else -42;
    if (x < lower_bound) {
        return if (@mod(x, 2) > 1) -0.0 else 0.0;
    }
    // above this, result overflows
    // gamma(+inf) = +inf
    const upper_bound = if (T == f64) 172 else 36;
    if (x > upper_bound) {
        return std.math.inf(T);
    }

    const abs = @abs(x);
    // perfect precision here
    if (abs < 0x1p-54) {
        return 1 / x;
    }

    const base = abs + lanczos_minus_half;
    const exponent = abs - 0.5;
    // error of y for correction, see
    // https://github.com/python/cpython/blob/5dc79e3d7f26a6a871a89ce3efc9f1bcee7bb447/Modules/mathmodule.c#L286-L324
    const e = if (abs > lanczos_minus_half)
        base - abs - lanczos_minus_half
    else
        base - lanczos_minus_half - abs;
    const correction = lanczos * e / base;
    const initial = series(T, abs) * @exp(-base);

    // use reflection formula for negatives
    if (x < 0) {
        const reflected = -std.math.pi / (abs * sinpi(T, abs) * initial);
        const corrected = reflected - reflected * correction;
        const half_pow = std.math.pow(T, base, -0.5 * exponent);
        return corrected * half_pow * half_pow;
    } else {
        const corrected = initial + initial * correction;
        const half_pow = std.math.pow(T, base, 0.5 * exponent);
        return corrected * half_pow * half_pow;
    }
}

/// Returns the natural logarithm of the absolute value of the gamma function.
///
/// Special Cases:
///  - lgamma(+-nan) = nan
///  - lgamma(+-inf) = +inf
///  - lgamma(n)     = +inf for negative integers
///  - lgamma(+-0.0) = +inf
///  - lgamma(1)     = +0.0
///  - lgamma(2)     = +0.0
pub fn lgamma(comptime T: type, x: T) T {
    if (T != f32 and T != f64) {
        @compileError("gamma not implemented for " ++ @typeName(T));
    }
    // common integer case first
    if (x == @trunc(x)) {
        // lgamma(-inf)  = +inf
        // lgamma(n)     = +inf for negative integers
        // lgamma(+-0.0) = +inf
        if (x <= 0) {
            return std.math.inf(T);
        }
        // lgamma(1) = +0.0
        // lgamma(2) = +0.0
        if (x < integer_result_table.len) {
            const i = @as(u8, @intFromFloat(x));
            return @log(@as(T, @floatCast(integer_result_table[i])));
        }
        // lgamma(+inf) = +inf
        if (std.math.isPositiveInf(x)) {
            return x;
        }
    }

    const abs = @abs(x);
    // perfect precision here
    if (abs < 0x1p-54) {
        return -@log(abs);
    }
    // obvious approach when overflow is not a problem
    const upper_bound = if (T == f64) 128 else 26;
    if (abs < upper_bound) {
        return @log(@abs(gamma(T, x)));
    }

    const log_base = @log(abs + lanczos_minus_half) - 1;
    const exponent = abs - 0.5;
    const log_series = @log(series(T, abs));
    const initial = exponent * log_base + log_series - lanczos;

    // use reflection formula for negatives
    if (x < 0) {
        const reflected = std.math.pi / (abs * sinpi(T, abs));
        return @log(@abs(reflected)) - initial;
    }
    return initial;
}

// table of factorials for integer early return
// stops at 22 because 23 isn't representable with full precision on f64
const integer_result_table = [_]f64{
    std.math.inf(f64), // gamma(+0.0)
    1, // gamma(1)
    1, // ...
    2,
    6,
    24,
    120,
    720,
    5040,
    40320,
    362880,
    3628800,
    39916800,
    479001600,
    6227020800,
    87178291200,
    1307674368000,
    20922789888000,
    355687428096000,
    6402373705728000,
    121645100408832000,
    2432902008176640000,
    51090942171709440000, // gamma(22)
};

// "g" constant, arbitrary
const lanczos = 6.024680040776729583740234375;
const lanczos_minus_half = lanczos - 0.5;

fn series(comptime T: type, abs: T) T {
    const numerator = [_]T{
        23531376880.410759688572007674451636754734846804940,
        42919803642.649098768957899047001988850926355848959,
        35711959237.355668049440185451547166705960488635843,
        17921034426.037209699919755754458931112671403265390,
        6039542586.3520280050642916443072979210699388420708,
        1439720407.3117216736632230727949123939715485786772,
        248874557.86205415651146038641322942321632125127801,
        31426415.585400194380614231628318205362874684987640,
        2876370.6289353724412254090516208496135991145378768,
        186056.26539522349504029498971604569928220784236328,
        8071.6720023658162106380029022722506138218516325024,
        210.82427775157934587250973392071336271166969580291,
        2.5066282746310002701649081771338373386264310793408,
    };
    const denominator = [_]T{
        0,
        39916800,
        120543840,
        150917976,
        105258076,
        45995730,
        13339535,
        2637558,
        357423,
        32670,
        1925,
        66,
        1,
    };
    var num: T = 0;
    var den: T = 0;
    // split to avoid overflow
    if (abs < 8) {
        // big abs would overflow here
        for (0..numerator.len) |i| {
            num = num * abs + numerator[numerator.len - 1 - i];
            den = den * abs + denominator[numerator.len - 1 - i];
        }
    } else {
        // small abs would overflow here
        for (0..numerator.len) |i| {
            num = num / abs + numerator[i];
            den = den / abs + denominator[i];
        }
    }
    return num / den;
}

// precise sin(pi * x)
// but not for integer x or |x| < 2^-54, we handle those already
fn sinpi(comptime T: type, x: T) T {
    const xmod2 = @mod(x, 2); // [0, 2]
    const n = (@as(u8, @intFromFloat(4 * xmod2)) + 1) / 2; // {0, 1, 2, 3, 4}
    const y = xmod2 - 0.5 * @as(T, @floatFromInt(n)); // [-0.25, 0.25]
    return switch (n) {
        0, 4 => @sin(std.math.pi * y),
        1 => @cos(std.math.pi * y),
        2 => -@sin(std.math.pi * y),
        3 => -@cos(std.math.pi * y),
        else => unreachable,
    };
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqRel = std.testing.expectApproxEqRel;

test gamma {
    inline for (&.{ f32, f64 }) |T| {
        const eps = @sqrt(std.math.floatEps(T));
        try expectApproxEqRel(@as(T, 120), gamma(T, 6), eps);
        try expectApproxEqRel(@as(T, 362880), gamma(T, 10), eps);
        try expectApproxEqRel(@as(T, 6402373705728000), gamma(T, 19), eps);

        try expectApproxEqRel(@as(T, 332.7590766955334570), gamma(T, 0.003), eps);
        try expectApproxEqRel(@as(T, 1.377260301981044573), gamma(T, 0.654), eps);
        try expectApproxEqRel(@as(T, 1.025393882573518478), gamma(T, 0.959), eps);

        try expectApproxEqRel(@as(T, 7.361898021467681690), gamma(T, 4.16), eps);
        try expectApproxEqRel(@as(T, 198337.2940287730753), gamma(T, 9.73), eps);
        try expectApproxEqRel(@as(T, 113718145797241.1666), gamma(T, 17.6), eps);

        try expectApproxEqRel(@as(T, -1.13860211111081424930673), gamma(T, -2.80), eps);
        try expectApproxEqRel(@as(T, 0.00018573407931875070158), gamma(T, -7.74), eps);
        try expectApproxEqRel(@as(T, -0.00000001647990903942825), gamma(T, -12.1), eps);
    }
}

test "gamma.special" {
    if (builtin.cpu.arch.isArmOrThumb() and builtin.target.floatAbi() == .soft) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/21234

    inline for (&.{ f32, f64 }) |T| {
        try expect(std.math.isNan(gamma(T, -std.math.nan(T))));
        try expect(std.math.isNan(gamma(T, std.math.nan(T))));
        try expect(std.math.isNan(gamma(T, -std.math.inf(T))));

        try expect(std.math.isNan(gamma(T, -4)));
        try expect(std.math.isNan(gamma(T, -11)));
        try expect(std.math.isNan(gamma(T, -78)));

        try expectEqual(-std.math.inf(T), gamma(T, -0.0));
        try expectEqual(std.math.inf(T), gamma(T, 0.0));

        try expect(std.math.isNegativeZero(gamma(T, -200.5)));
        try expect(std.math.isPositiveZero(gamma(T, -201.5)));
        try expect(std.math.isNegativeZero(gamma(T, -202.5)));

        try expectEqual(std.math.inf(T), gamma(T, 200));
        try expectEqual(std.math.inf(T), gamma(T, 201));
        try expectEqual(std.math.inf(T), gamma(T, 202));

        try expectEqual(std.math.inf(T), gamma(T, std.math.inf(T)));
    }
}

test lgamma {
    inline for (&.{ f32, f64 }) |T| {
        const eps = @sqrt(std.math.floatEps(T));
        try expectApproxEqRel(@as(T, @log(24.0)), lgamma(T, 5), eps);
        try expectApproxEqRel(@as(T, @log(20922789888000.0)), lgamma(T, 17), eps);
        try expectApproxEqRel(@as(T, @log(2432902008176640000.0)), lgamma(T, 21), eps);

        try expectApproxEqRel(@as(T, 2.201821590438859327), lgamma(T, 0.105), eps);
        try expectApproxEqRel(@as(T, 1.275416975248413231), lgamma(T, 0.253), eps);
        try expectApproxEqRel(@as(T, 0.130463884049976732), lgamma(T, 0.823), eps);

        try expectApproxEqRel(@as(T, 43.24395772148497989), lgamma(T, 21.3), eps);
        try expectApproxEqRel(@as(T, 110.6908958012102623), lgamma(T, 41.1), eps);
        try expectApproxEqRel(@as(T, 215.2123266224689711), lgamma(T, 67.4), eps);

        try expectApproxEqRel(@as(T, -122.605958469563489), lgamma(T, -43.6), eps);
        try expectApproxEqRel(@as(T, -278.633885462703133), lgamma(T, -81.4), eps);
        try expectApproxEqRel(@as(T, -333.247676253238363), lgamma(T, -93.6), eps);
    }
}

test "lgamma.special" {
    inline for (&.{ f32, f64 }) |T| {
        try expect(std.math.isNan(lgamma(T, -std.math.nan(T))));
        try expect(std.math.isNan(lgamma(T, std.math.nan(T))));

        try expectEqual(std.math.inf(T), lgamma(T, -std.math.inf(T)));
        try expectEqual(std.math.inf(T), lgamma(T, std.math.inf(T)));

        try expectEqual(std.math.inf(T), lgamma(T, -5));
        try expectEqual(std.math.inf(T), lgamma(T, -8));
        try expectEqual(std.math.inf(T), lgamma(T, -15));

        try expectEqual(std.math.inf(T), lgamma(T, -0.0));
        try expectEqual(std.math.inf(T), lgamma(T, 0.0));

        try expect(std.math.isPositiveZero(lgamma(T, 1)));
        try expect(std.math.isPositiveZero(lgamma(T, 2)));
    }
}

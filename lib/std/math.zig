const builtin = @import("builtin");
const std = @import("std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;

/// Euler's number (e)
pub const e = 2.71828182845904523536028747135266249775724709369995;

/// Archimedes' constant (π)
pub const pi = 3.14159265358979323846264338327950288419716939937510;

/// Phi or Golden ratio constant (Φ) = (1 + sqrt(5))/2
pub const phi = 1.6180339887498948482045868343656381177203091798057628621;

/// Circle constant (τ)
pub const tau = 2 * pi;

/// log2(e)
pub const log2e = 1.442695040888963407359924681001892137;

/// log10(e)
pub const log10e = 0.434294481903251827651128918916605082;

/// ln(2)
pub const ln2 = 0.693147180559945309417232121458176568;

/// ln(10)
pub const ln10 = 2.302585092994045684017991454684364208;

/// 2/sqrt(π)
pub const two_sqrtpi = 1.128379167095512573896158903121545172;

/// sqrt(2)
pub const sqrt2 = 1.414213562373095048801688724209698079;

/// 1/sqrt(2)
pub const sqrt1_2 = 0.707106781186547524400844362104849039;

/// pi/180.0
pub const rad_per_deg = 0.0174532925199432957692369076848861271344287188854172545609719144;

/// 180.0/pi
pub const deg_per_rad = 57.295779513082320876798154814105170332405472466564321549160243861;

pub const floatExponentBits = @import("math/float.zig").floatExponentBits;
pub const floatMantissaBits = @import("math/float.zig").floatMantissaBits;
pub const floatFractionalBits = @import("math/float.zig").floatFractionalBits;
pub const floatExponentMin = @import("math/float.zig").floatExponentMin;
pub const floatExponentMax = @import("math/float.zig").floatExponentMax;
pub const floatTrueMin = @import("math/float.zig").floatTrueMin;
pub const floatMin = @import("math/float.zig").floatMin;
pub const floatMax = @import("math/float.zig").floatMax;
pub const floatEps = @import("math/float.zig").floatEps;
pub const inf = @import("math/float.zig").inf;
pub const nan = @import("math/float.zig").nan;
pub const snan = @import("math/float.zig").snan;

/// Performs an approximate comparison of two floating point values `x` and `y`.
/// Returns true if the absolute difference between them is less or equal than
/// the specified tolerance.
///
/// The `tolerance` parameter is the absolute tolerance used when determining if
/// the two numbers are close enough; a good value for this parameter is a small
/// multiple of `floatEps(T)`.
///
/// Note that this function is recommended for comparing small numbers
/// around zero; using `approxEqRel` is suggested otherwise.
///
/// NaN values are never considered equal to any value.
pub fn approxEqAbs(comptime T: type, x: T, y: T, tolerance: T) bool {
    assert(@typeInfo(T) == .Float or @typeInfo(T) == .ComptimeFloat);
    assert(tolerance >= 0);

    // Fast path for equal values (and signed zeros and infinites).
    if (x == y)
        return true;

    if (isNan(x) or isNan(y))
        return false;

    return @abs(x - y) <= tolerance;
}

/// Performs an approximate comparison of two floating point values `x` and `y`.
/// Returns true if the absolute difference between them is less or equal than
/// `max(|x|, |y|) * tolerance`, where `tolerance` is a positive number greater
/// than zero.
///
/// The `tolerance` parameter is the relative tolerance used when determining if
/// the two numbers are close enough; a good value for this parameter is usually
/// `sqrt(floatEps(T))`, meaning that the two numbers are considered equal if at
/// least half of the digits are equal.
///
/// Note that for comparisons of small numbers around zero this function won't
/// give meaningful results, use `approxEqAbs` instead.
///
/// NaN values are never considered equal to any value.
pub fn approxEqRel(comptime T: type, x: T, y: T, tolerance: T) bool {
    assert(@typeInfo(T) == .Float or @typeInfo(T) == .ComptimeFloat);
    assert(tolerance > 0);

    // Fast path for equal values (and signed zeros and infinites).
    if (x == y)
        return true;

    if (isNan(x) or isNan(y))
        return false;

    return @abs(x - y) <= @max(@abs(x), @abs(y)) * tolerance;
}

test approxEqAbs {
    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        const eps_value = comptime floatEps(T);
        const min_value = comptime floatMin(T);

        try testing.expect(approxEqAbs(T, 0.0, 0.0, eps_value));
        try testing.expect(approxEqAbs(T, -0.0, -0.0, eps_value));
        try testing.expect(approxEqAbs(T, 0.0, -0.0, eps_value));
        try testing.expect(!approxEqAbs(T, 1.0 + 2 * eps_value, 1.0, eps_value));
        try testing.expect(approxEqAbs(T, 1.0 + 1 * eps_value, 1.0, eps_value));
        try testing.expect(approxEqAbs(T, min_value, 0.0, eps_value * 2));
        try testing.expect(approxEqAbs(T, -min_value, 0.0, eps_value * 2));
    }

    comptime {
        // `comptime_float` is guaranteed to have the same precision and operations of
        // the largest other floating point type, which is f128 but it doesn't have a
        // defined layout so we can't rely on `@bitCast` to construct the smallest
        // possible epsilon value like we do in the tests above. In the same vein, we
        // also can't represent a max/min, `NaN` or `Inf` values.
        const eps_value = 1e-4;

        try testing.expect(approxEqAbs(comptime_float, 0.0, 0.0, eps_value));
        try testing.expect(approxEqAbs(comptime_float, -0.0, -0.0, eps_value));
        try testing.expect(approxEqAbs(comptime_float, 0.0, -0.0, eps_value));
        try testing.expect(!approxEqAbs(comptime_float, 1.0 + 2 * eps_value, 1.0, eps_value));
        try testing.expect(approxEqAbs(comptime_float, 1.0 + 1 * eps_value, 1.0, eps_value));
    }
}

test approxEqRel {
    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        const eps_value = comptime floatEps(T);
        const sqrt_eps_value = comptime sqrt(eps_value);
        const nan_value = comptime nan(T);
        const inf_value = comptime inf(T);
        const min_value = comptime floatMin(T);

        try testing.expect(approxEqRel(T, 1.0, 1.0, sqrt_eps_value));
        try testing.expect(!approxEqRel(T, 1.0, 0.0, sqrt_eps_value));
        try testing.expect(!approxEqRel(T, 1.0, nan_value, sqrt_eps_value));
        try testing.expect(!approxEqRel(T, nan_value, nan_value, sqrt_eps_value));
        try testing.expect(approxEqRel(T, inf_value, inf_value, sqrt_eps_value));
        try testing.expect(approxEqRel(T, min_value, min_value, sqrt_eps_value));
        try testing.expect(approxEqRel(T, -min_value, -min_value, sqrt_eps_value));
    }

    comptime {
        // `comptime_float` is guaranteed to have the same precision and operations of
        // the largest other floating point type, which is f128 but it doesn't have a
        // defined layout so we can't rely on `@bitCast` to construct the smallest
        // possible epsilon value like we do in the tests above. In the same vein, we
        // also can't represent a max/min, `NaN` or `Inf` values.
        const eps_value = 1e-4;
        const sqrt_eps_value = sqrt(eps_value);

        try testing.expect(approxEqRel(comptime_float, 1.0, 1.0, sqrt_eps_value));
        try testing.expect(!approxEqRel(comptime_float, 1.0, 0.0, sqrt_eps_value));
    }
}

pub fn raiseInvalid() void {
    // Raise INVALID fpu exception
}

pub fn raiseUnderflow() void {
    // Raise UNDERFLOW fpu exception
}

pub fn raiseOverflow() void {
    // Raise OVERFLOW fpu exception
}

pub fn raiseInexact() void {
    // Raise INEXACT fpu exception
}

pub fn raiseDivByZero() void {
    // Raise INEXACT fpu exception
}

pub const isNan = @import("math/isnan.zig").isNan;
pub const isSignalNan = @import("math/isnan.zig").isSignalNan;
pub const frexp = @import("math/frexp.zig").frexp;
pub const Frexp = @import("math/frexp.zig").Frexp;
pub const modf = @import("math/modf.zig").modf;
pub const Modf = @import("math/modf.zig").Modf;
pub const copysign = @import("math/copysign.zig").copysign;
pub const isFinite = @import("math/isfinite.zig").isFinite;
pub const isInf = @import("math/isinf.zig").isInf;
pub const isPositiveInf = @import("math/isinf.zig").isPositiveInf;
pub const isNegativeInf = @import("math/isinf.zig").isNegativeInf;
pub const isPositiveZero = @import("math/iszero.zig").isPositiveZero;
pub const isNegativeZero = @import("math/iszero.zig").isNegativeZero;
pub const isNormal = @import("math/isnormal.zig").isNormal;
pub const nextAfter = @import("math/nextafter.zig").nextAfter;
pub const signbit = @import("math/signbit.zig").signbit;
pub const scalbn = @import("math/scalbn.zig").scalbn;
pub const ldexp = @import("math/ldexp.zig").ldexp;
pub const pow = @import("math/pow.zig").pow;
pub const powi = @import("math/powi.zig").powi;
pub const sqrt = @import("math/sqrt.zig").sqrt;
pub const cbrt = @import("math/cbrt.zig").cbrt;
pub const acos = @import("math/acos.zig").acos;
pub const asin = @import("math/asin.zig").asin;
pub const atan = @import("math/atan.zig").atan;
pub const atan2 = @import("math/atan2.zig").atan2;
pub const hypot = @import("math/hypot.zig").hypot;
pub const expm1 = @import("math/expm1.zig").expm1;
pub const ilogb = @import("math/ilogb.zig").ilogb;
pub const log = @import("math/log.zig").log;
pub const log2 = @import("math/log2.zig").log2;
pub const log10 = @import("math/log10.zig").log10;
pub const log10_int = @import("math/log10.zig").log10_int;
pub const log_int = @import("math/log_int.zig").log_int;
pub const log1p = @import("math/log1p.zig").log1p;
pub const asinh = @import("math/asinh.zig").asinh;
pub const acosh = @import("math/acosh.zig").acosh;
pub const atanh = @import("math/atanh.zig").atanh;
pub const sinh = @import("math/sinh.zig").sinh;
pub const cosh = @import("math/cosh.zig").cosh;
pub const tanh = @import("math/tanh.zig").tanh;
pub const gcd = @import("math/gcd.zig").gcd;
pub const gamma = @import("math/gamma.zig").gamma;
pub const lgamma = @import("math/gamma.zig").lgamma;

/// Sine trigonometric function on a floating point number.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @sin
pub inline fn sin(value: anytype) @TypeOf(value) {
    return @sin(value);
}

/// Cosine trigonometric function on a floating point number.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @cos
pub inline fn cos(value: anytype) @TypeOf(value) {
    return @cos(value);
}

/// Tangent trigonometric function on a floating point number.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @tan
pub inline fn tan(value: anytype) @TypeOf(value) {
    return @tan(value);
}

/// Converts an angle in radians to degrees. T must be a float or comptime number or a vector of floats.
pub fn radiansToDegrees(ang: anytype) if (@TypeOf(ang) == comptime_int) comptime_float else @TypeOf(ang) {
    const T = @TypeOf(ang);
    switch (@typeInfo(T)) {
        .Float, .ComptimeFloat, .ComptimeInt => return ang * deg_per_rad,
        .Vector => |V| if (@typeInfo(V.child) == .Float) return ang * @as(T, @splat(deg_per_rad)),
        else => {},
    }
    @compileError("Input must be float or a comptime number, or a vector of floats.");
}

test radiansToDegrees {
    const zero: f32 = 0;
    const half_pi: f32 = pi / 2.0;
    const neg_quart_pi: f32 = -pi / 4.0;
    const one_pi: f32 = pi;
    const two_pi: f32 = 2.0 * pi;
    try std.testing.expectApproxEqAbs(@as(f32, 0), radiansToDegrees(zero), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 90), radiansToDegrees(half_pi), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -45), radiansToDegrees(neg_quart_pi), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 180), radiansToDegrees(one_pi), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 360), radiansToDegrees(two_pi), 1e-6);

    const result = radiansToDegrees(@Vector(4, f32){
        half_pi,
        neg_quart_pi,
        one_pi,
        two_pi,
    });
    try std.testing.expectApproxEqAbs(@as(f32, 90), result[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -45), result[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 180), result[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 360), result[3], 1e-6);
}

/// Converts an angle in degrees to radians. T must be a float or comptime number or a vector of floats.
pub fn degreesToRadians(ang: anytype) if (@TypeOf(ang) == comptime_int) comptime_float else @TypeOf(ang) {
    const T = @TypeOf(ang);
    switch (@typeInfo(T)) {
        .Float, .ComptimeFloat, .ComptimeInt => return ang * rad_per_deg,
        .Vector => |V| if (@typeInfo(V.child) == .Float) return ang * @as(T, @splat(rad_per_deg)),
        else => {},
    }
    @compileError("Input must be float or a comptime number, or a vector of floats.");
}

test degreesToRadians {
    const ninety: f32 = 90;
    const neg_two_seventy: f32 = -270;
    const three_sixty: f32 = 360;
    try std.testing.expectApproxEqAbs(@as(f32, pi / 2.0), degreesToRadians(ninety), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -3 * pi / 2.0), degreesToRadians(neg_two_seventy), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2 * pi), degreesToRadians(three_sixty), 1e-6);

    const result = degreesToRadians(@Vector(3, f32){
        ninety,
        neg_two_seventy,
        three_sixty,
    });
    try std.testing.expectApproxEqAbs(@as(f32, pi / 2.0), result[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -3 * pi / 2.0), result[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2 * pi), result[2], 1e-6);
}

/// Base-e exponential function on a floating point number.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @exp
pub inline fn exp(value: anytype) @TypeOf(value) {
    return @exp(value);
}

/// Base-2 exponential function on a floating point number.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @exp2
pub inline fn exp2(value: anytype) @TypeOf(value) {
    return @exp2(value);
}

pub const complex = @import("math/complex.zig");
pub const Complex = complex.Complex;

pub const big = @import("math/big.zig");

test {
    _ = floatExponentBits;
    _ = floatMantissaBits;
    _ = floatFractionalBits;
    _ = floatExponentMin;
    _ = floatExponentMax;
    _ = floatTrueMin;
    _ = floatMin;
    _ = floatMax;
    _ = floatEps;
    _ = inf;
    _ = nan;
    _ = snan;
    _ = isNan;
    _ = isSignalNan;
    _ = frexp;
    _ = Frexp;
    _ = modf;
    _ = Modf;
    _ = copysign;
    _ = isFinite;
    _ = isInf;
    _ = isPositiveInf;
    _ = isNegativeInf;
    _ = isNormal;
    _ = nextAfter;
    _ = signbit;
    _ = scalbn;
    _ = ldexp;
    _ = pow;
    _ = powi;
    _ = sqrt;
    _ = cbrt;
    _ = acos;
    _ = asin;
    _ = atan;
    _ = atan2;
    _ = hypot;
    _ = expm1;
    _ = ilogb;
    _ = log;
    _ = log2;
    _ = log10;
    _ = log10_int;
    _ = log_int;
    _ = log1p;
    _ = asinh;
    _ = acosh;
    _ = atanh;
    _ = sinh;
    _ = cosh;
    _ = tanh;
    _ = gcd;
    _ = gamma;
    _ = lgamma;

    _ = complex;
    _ = Complex;

    _ = big;
}

/// Given two types, returns the smallest one which is capable of holding the
/// full range of the minimum value.
pub fn Min(comptime A: type, comptime B: type) type {
    switch (@typeInfo(A)) {
        .Int => |a_info| switch (@typeInfo(B)) {
            .Int => |b_info| if (a_info.signedness == .unsigned and b_info.signedness == .unsigned) {
                if (a_info.bits < b_info.bits) {
                    return A;
                } else {
                    return B;
                }
            },
            else => {},
        },
        else => {},
    }
    return @TypeOf(@as(A, 0) + @as(B, 0));
}

/// Odd sawtooth function
/// ```
///         |
///      /  | /    /
///     /   |/    /
///  --/----/----/--
///   /    /|   /
///  /    / |  /
///         |
/// ```
/// Limit x to the half-open interval [-r, r).
pub fn wrap(x: anytype, r: anytype) @TypeOf(x) {
    const info_x = @typeInfo(@TypeOf(x));
    const info_r = @typeInfo(@TypeOf(r));
    if (info_x == .Int and info_x.Int.signedness != .signed) {
        @compileError("x must be floating point, comptime integer, or signed integer.");
    }
    switch (info_r) {
        .Int => {
            // in the rare usecase of r not being comptime_int or float,
            // take the penalty of having an intermediary type conversion,
            // otherwise the alternative is to unwind iteratively to avoid overflow
            const R = comptime do: {
                var info = info_r;
                info.Int.bits += 1;
                info.Int.signedness = .signed;
                break :do @Type(info);
            };
            const radius: if (info_r.Int.signedness == .signed) @TypeOf(r) else R = r;
            return @intCast(@mod(x - radius, 2 * @as(R, r)) - r); // provably impossible to overflow
        },
        else => {
            return @mod(x - r, 2 * r) - r;
        },
    }
}
test wrap {
    // Within range
    try testing.expect(wrap(@as(i32, -75), @as(i32, 180)) == -75);
    try testing.expect(wrap(@as(i32, -75), @as(i32, -180)) == -75);
    // Below
    try testing.expect(wrap(@as(i32, -225), @as(i32, 180)) == 135);
    try testing.expect(wrap(@as(i32, -225), @as(i32, -180)) == 135);
    // Above
    try testing.expect(wrap(@as(i32, 361), @as(i32, 180)) == 1);
    try testing.expect(wrap(@as(i32, 361), @as(i32, -180)) == 1);

    // One period, right limit, positive r
    try testing.expect(wrap(@as(i32, 180), @as(i32, 180)) == -180);
    // One period, left limit, positive r
    try testing.expect(wrap(@as(i32, -180), @as(i32, 180)) == -180);
    // One period, right limit, negative r
    try testing.expect(wrap(@as(i32, 180), @as(i32, -180)) == 180);
    // One period, left limit, negative r
    try testing.expect(wrap(@as(i32, -180), @as(i32, -180)) == 180);

    // Two periods, right limit, positive r
    try testing.expect(wrap(@as(i32, 540), @as(i32, 180)) == -180);
    // Two periods, left limit, positive r
    try testing.expect(wrap(@as(i32, -540), @as(i32, 180)) == -180);
    // Two periods, right limit, negative r
    try testing.expect(wrap(@as(i32, 540), @as(i32, -180)) == 180);
    // Two periods, left limit, negative r
    try testing.expect(wrap(@as(i32, -540), @as(i32, -180)) == 180);

    // Floating point
    try testing.expect(wrap(@as(f32, 1.125), @as(f32, 1.0)) == -0.875);
    try testing.expect(wrap(@as(f32, -127.5), @as(f32, 180)) == -127.5);

    // Mix of comptime and non-comptime
    var i: i32 = 1;
    _ = &i;
    try testing.expect(wrap(i, 10) == 1);

    const limit: i32 = 180;
    // Within range
    try testing.expect(wrap(@as(i32, -75), limit) == -75);
    // Below
    try testing.expect(wrap(@as(i32, -225), limit) == 135);
    // Above
    try testing.expect(wrap(@as(i32, 361), limit) == 1);
}

/// Odd ramp function
/// ```
///         |  _____
///         | /
///         |/
///  -------/-------
///        /|
///  _____/ |
///         |
/// ```
/// Limit val to the inclusive range [lower, upper].
pub fn clamp(val: anytype, lower: anytype, upper: anytype) @TypeOf(val, lower, upper) {
    assert(lower <= upper);
    return @max(lower, @min(val, upper));
}
test clamp {
    // Within range
    try testing.expect(std.math.clamp(@as(i32, -1), @as(i32, -4), @as(i32, 7)) == -1);
    // Below
    try testing.expect(std.math.clamp(@as(i32, -5), @as(i32, -4), @as(i32, 7)) == -4);
    // Above
    try testing.expect(std.math.clamp(@as(i32, 8), @as(i32, -4), @as(i32, 7)) == 7);

    // Floating point
    try testing.expect(std.math.clamp(@as(f32, 1.1), @as(f32, 0.0), @as(f32, 1.0)) == 1.0);
    try testing.expect(std.math.clamp(@as(f32, -127.5), @as(f32, -200), @as(f32, -100)) == -127.5);

    // Mix of comptime and non-comptime
    var i: i32 = 1;
    _ = &i;
    try testing.expect(std.math.clamp(i, 0, 1) == 1);
}

/// Returns the product of a and b. Returns an error on overflow.
pub fn mul(comptime T: type, a: T, b: T) (error{Overflow}!T) {
    if (T == comptime_int) return a * b;
    const ov = @mulWithOverflow(a, b);
    if (ov[1] != 0) return error.Overflow;
    return ov[0];
}

/// Returns the sum of a and b. Returns an error on overflow.
pub fn add(comptime T: type, a: T, b: T) (error{Overflow}!T) {
    if (T == comptime_int) return a + b;
    const ov = @addWithOverflow(a, b);
    if (ov[1] != 0) return error.Overflow;
    return ov[0];
}

/// Returns a - b, or an error on overflow.
pub fn sub(comptime T: type, a: T, b: T) (error{Overflow}!T) {
    if (T == comptime_int) return a - b;
    const ov = @subWithOverflow(a, b);
    if (ov[1] != 0) return error.Overflow;
    return ov[0];
}

pub fn negate(x: anytype) !@TypeOf(x) {
    return sub(@TypeOf(x), 0, x);
}

/// Shifts a left by shift_amt. Returns an error on overflow. shift_amt
/// is unsigned.
pub fn shlExact(comptime T: type, a: T, shift_amt: Log2Int(T)) !T {
    if (T == comptime_int) return a << shift_amt;
    const ov = @shlWithOverflow(a, shift_amt);
    if (ov[1] != 0) return error.Overflow;
    return ov[0];
}

/// Shifts left. Overflowed bits are truncated.
/// A negative shift amount results in a right shift.
pub fn shl(comptime T: type, a: T, shift_amt: anytype) T {
    const abs_shift_amt = @abs(shift_amt);

    const casted_shift_amt = blk: {
        if (@typeInfo(T) == .Vector) {
            const C = @typeInfo(T).Vector.child;
            const len = @typeInfo(T).Vector.len;
            if (abs_shift_amt >= @typeInfo(C).Int.bits) return @splat(0);
            break :blk @as(@Vector(len, Log2Int(C)), @splat(@as(Log2Int(C), @intCast(abs_shift_amt))));
        } else {
            if (abs_shift_amt >= @typeInfo(T).Int.bits) return 0;
            break :blk @as(Log2Int(T), @intCast(abs_shift_amt));
        }
    };

    if (@TypeOf(shift_amt) == comptime_int or @typeInfo(@TypeOf(shift_amt)).Int.signedness == .signed) {
        if (shift_amt < 0) {
            return a >> casted_shift_amt;
        }
    }

    return a << casted_shift_amt;
}

test shl {
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/12012
        return error.SkipZigTest;
    }

    try testing.expect(shl(u8, 0b11111111, @as(usize, 3)) == 0b11111000);
    try testing.expect(shl(u8, 0b11111111, @as(usize, 8)) == 0);
    try testing.expect(shl(u8, 0b11111111, @as(usize, 9)) == 0);
    try testing.expect(shl(u8, 0b11111111, @as(isize, -2)) == 0b00111111);
    try testing.expect(shl(u8, 0b11111111, 3) == 0b11111000);
    try testing.expect(shl(u8, 0b11111111, 8) == 0);
    try testing.expect(shl(u8, 0b11111111, 9) == 0);
    try testing.expect(shl(u8, 0b11111111, -2) == 0b00111111);
    try testing.expect(shl(@Vector(1, u32), @Vector(1, u32){42}, @as(usize, 1))[0] == @as(u32, 42) << 1);
    try testing.expect(shl(@Vector(1, u32), @Vector(1, u32){42}, @as(isize, -1))[0] == @as(u32, 42) >> 1);
    try testing.expect(shl(@Vector(1, u32), @Vector(1, u32){42}, 33)[0] == 0);
}

/// Shifts right. Overflowed bits are truncated.
/// A negative shift amount results in a left shift.
pub fn shr(comptime T: type, a: T, shift_amt: anytype) T {
    const abs_shift_amt = @abs(shift_amt);

    const casted_shift_amt = blk: {
        if (@typeInfo(T) == .Vector) {
            const C = @typeInfo(T).Vector.child;
            const len = @typeInfo(T).Vector.len;
            if (abs_shift_amt >= @typeInfo(C).Int.bits) return @splat(0);
            break :blk @as(@Vector(len, Log2Int(C)), @splat(@as(Log2Int(C), @intCast(abs_shift_amt))));
        } else {
            if (abs_shift_amt >= @typeInfo(T).Int.bits) return 0;
            break :blk @as(Log2Int(T), @intCast(abs_shift_amt));
        }
    };

    if (@TypeOf(shift_amt) == comptime_int or @typeInfo(@TypeOf(shift_amt)).Int.signedness == .signed) {
        if (shift_amt < 0) {
            return a << casted_shift_amt;
        }
    }

    return a >> casted_shift_amt;
}

test shr {
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/12012
        return error.SkipZigTest;
    }

    try testing.expect(shr(u8, 0b11111111, @as(usize, 3)) == 0b00011111);
    try testing.expect(shr(u8, 0b11111111, @as(usize, 8)) == 0);
    try testing.expect(shr(u8, 0b11111111, @as(usize, 9)) == 0);
    try testing.expect(shr(u8, 0b11111111, @as(isize, -2)) == 0b11111100);
    try testing.expect(shr(u8, 0b11111111, 3) == 0b00011111);
    try testing.expect(shr(u8, 0b11111111, 8) == 0);
    try testing.expect(shr(u8, 0b11111111, 9) == 0);
    try testing.expect(shr(u8, 0b11111111, -2) == 0b11111100);
    try testing.expect(shr(@Vector(1, u32), @Vector(1, u32){42}, @as(usize, 1))[0] == @as(u32, 42) >> 1);
    try testing.expect(shr(@Vector(1, u32), @Vector(1, u32){42}, @as(isize, -1))[0] == @as(u32, 42) << 1);
    try testing.expect(shr(@Vector(1, u32), @Vector(1, u32){42}, 33)[0] == 0);
}

/// Rotates right. Only unsigned values can be rotated.  Negative shift
/// values result in shift modulo the bit count.
pub fn rotr(comptime T: type, x: T, r: anytype) T {
    if (@typeInfo(T) == .Vector) {
        const C = @typeInfo(T).Vector.child;
        if (C == u0) return 0;

        if (@typeInfo(C).Int.signedness == .signed) {
            @compileError("cannot rotate signed integers");
        }
        const ar: Log2Int(C) = @intCast(@mod(r, @typeInfo(C).Int.bits));
        return (x >> @splat(ar)) | (x << @splat(1 + ~ar));
    } else if (@typeInfo(T).Int.signedness == .signed) {
        @compileError("cannot rotate signed integer");
    } else {
        if (T == u0) return 0;

        if (comptime isPowerOfTwo(@typeInfo(T).Int.bits)) {
            const ar: Log2Int(T) = @intCast(@mod(r, @typeInfo(T).Int.bits));
            return x >> ar | x << (1 +% ~ar);
        } else {
            const ar = @mod(r, @typeInfo(T).Int.bits);
            return shr(T, x, ar) | shl(T, x, @typeInfo(T).Int.bits - ar);
        }
    }
}

test rotr {
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/12012
        return error.SkipZigTest;
    }

    try testing.expect(rotr(u0, 0b0, @as(usize, 3)) == 0b0);
    try testing.expect(rotr(u5, 0b00001, @as(usize, 0)) == 0b00001);
    try testing.expect(rotr(u6, 0b000001, @as(usize, 7)) == 0b100000);
    try testing.expect(rotr(u8, 0b00000001, @as(usize, 0)) == 0b00000001);
    try testing.expect(rotr(u8, 0b00000001, @as(usize, 9)) == 0b10000000);
    try testing.expect(rotr(u8, 0b00000001, @as(usize, 8)) == 0b00000001);
    try testing.expect(rotr(u8, 0b00000001, @as(usize, 4)) == 0b00010000);
    try testing.expect(rotr(u8, 0b00000001, @as(isize, -1)) == 0b00000010);
    try testing.expect(rotr(u12, 0o7777, 1) == 0o7777);
    try testing.expect(rotr(@Vector(1, u32), @Vector(1, u32){1}, @as(usize, 1))[0] == @as(u32, 1) << 31);
    try testing.expect(rotr(@Vector(1, u32), @Vector(1, u32){1}, @as(isize, -1))[0] == @as(u32, 1) << 1);
}

/// Rotates left. Only unsigned values can be rotated.  Negative shift
/// values result in shift modulo the bit count.
pub fn rotl(comptime T: type, x: T, r: anytype) T {
    if (@typeInfo(T) == .Vector) {
        const C = @typeInfo(T).Vector.child;
        if (C == u0) return 0;

        if (@typeInfo(C).Int.signedness == .signed) {
            @compileError("cannot rotate signed integers");
        }
        const ar: Log2Int(C) = @intCast(@mod(r, @typeInfo(C).Int.bits));
        return (x << @splat(ar)) | (x >> @splat(1 +% ~ar));
    } else if (@typeInfo(T).Int.signedness == .signed) {
        @compileError("cannot rotate signed integer");
    } else {
        if (T == u0) return 0;

        if (comptime isPowerOfTwo(@typeInfo(T).Int.bits)) {
            const ar: Log2Int(T) = @intCast(@mod(r, @typeInfo(T).Int.bits));
            return x << ar | x >> 1 +% ~ar;
        } else {
            const ar = @mod(r, @typeInfo(T).Int.bits);
            return shl(T, x, ar) | shr(T, x, @typeInfo(T).Int.bits - ar);
        }
    }
}

test rotl {
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/12012
        return error.SkipZigTest;
    }

    try testing.expect(rotl(u0, 0b0, @as(usize, 3)) == 0b0);
    try testing.expect(rotl(u5, 0b00001, @as(usize, 0)) == 0b00001);
    try testing.expect(rotl(u6, 0b000001, @as(usize, 7)) == 0b000010);
    try testing.expect(rotl(u8, 0b00000001, @as(usize, 0)) == 0b00000001);
    try testing.expect(rotl(u8, 0b00000001, @as(usize, 9)) == 0b00000010);
    try testing.expect(rotl(u8, 0b00000001, @as(usize, 8)) == 0b00000001);
    try testing.expect(rotl(u8, 0b00000001, @as(usize, 4)) == 0b00010000);
    try testing.expect(rotl(u8, 0b00000001, @as(isize, -1)) == 0b10000000);
    try testing.expect(rotl(u12, 0o7777, 1) == 0o7777);
    try testing.expect(rotl(@Vector(1, u32), @Vector(1, u32){1 << 31}, @as(usize, 1))[0] == 1);
    try testing.expect(rotl(@Vector(1, u32), @Vector(1, u32){1 << 31}, @as(isize, -1))[0] == @as(u32, 1) << 30);
}

/// Returns an unsigned int type that can hold the number of bits in T
/// - 1. Suitable for 0-based bit indices of T.
pub fn Log2Int(comptime T: type) type {
    // comptime ceil log2
    if (T == comptime_int) return comptime_int;
    comptime var count = 0;
    comptime var s = @typeInfo(T).Int.bits - 1;
    inline while (s != 0) : (s >>= 1) {
        count += 1;
    }

    return std.meta.Int(.unsigned, count);
}

/// Returns an unsigned int type that can hold the number of bits in T.
pub fn Log2IntCeil(comptime T: type) type {
    // comptime ceil log2
    if (T == comptime_int) return comptime_int;
    comptime var count = 0;
    comptime var s = @typeInfo(T).Int.bits;
    inline while (s != 0) : (s >>= 1) {
        count += 1;
    }

    return std.meta.Int(.unsigned, count);
}

/// Returns the smallest integer type that can hold both from and to.
pub fn IntFittingRange(comptime from: comptime_int, comptime to: comptime_int) type {
    assert(from <= to);
    if (from == 0 and to == 0) {
        return u0;
    }
    const signedness: std.builtin.Signedness = if (from < 0) .signed else .unsigned;
    const largest_positive_integer = @max(if (from < 0) (-from) - 1 else from, to); // two's complement
    const base = log2(largest_positive_integer);
    const upper = (1 << base) - 1;
    var magnitude_bits = if (upper >= largest_positive_integer) base else base + 1;
    if (signedness == .signed) {
        magnitude_bits += 1;
    }
    return std.meta.Int(signedness, magnitude_bits);
}

test IntFittingRange {
    try testing.expect(IntFittingRange(0, 0) == u0);
    try testing.expect(IntFittingRange(0, 1) == u1);
    try testing.expect(IntFittingRange(0, 2) == u2);
    try testing.expect(IntFittingRange(0, 3) == u2);
    try testing.expect(IntFittingRange(0, 4) == u3);
    try testing.expect(IntFittingRange(0, 7) == u3);
    try testing.expect(IntFittingRange(0, 8) == u4);
    try testing.expect(IntFittingRange(0, 9) == u4);
    try testing.expect(IntFittingRange(0, 15) == u4);
    try testing.expect(IntFittingRange(0, 16) == u5);
    try testing.expect(IntFittingRange(0, 17) == u5);
    try testing.expect(IntFittingRange(0, 4095) == u12);
    try testing.expect(IntFittingRange(2000, 4095) == u12);
    try testing.expect(IntFittingRange(0, 4096) == u13);
    try testing.expect(IntFittingRange(2000, 4096) == u13);
    try testing.expect(IntFittingRange(0, 4097) == u13);
    try testing.expect(IntFittingRange(2000, 4097) == u13);
    try testing.expect(IntFittingRange(0, 123456789123456798123456789) == u87);
    try testing.expect(IntFittingRange(0, 123456789123456798123456789123456789123456798123456789) == u177);

    try testing.expect(IntFittingRange(-1, -1) == i1);
    try testing.expect(IntFittingRange(-1, 0) == i1);
    try testing.expect(IntFittingRange(-1, 1) == i2);
    try testing.expect(IntFittingRange(-2, -2) == i2);
    try testing.expect(IntFittingRange(-2, -1) == i2);
    try testing.expect(IntFittingRange(-2, 0) == i2);
    try testing.expect(IntFittingRange(-2, 1) == i2);
    try testing.expect(IntFittingRange(-2, 2) == i3);
    try testing.expect(IntFittingRange(-1, 2) == i3);
    try testing.expect(IntFittingRange(-1, 3) == i3);
    try testing.expect(IntFittingRange(-1, 4) == i4);
    try testing.expect(IntFittingRange(-1, 7) == i4);
    try testing.expect(IntFittingRange(-1, 8) == i5);
    try testing.expect(IntFittingRange(-1, 9) == i5);
    try testing.expect(IntFittingRange(-1, 15) == i5);
    try testing.expect(IntFittingRange(-1, 16) == i6);
    try testing.expect(IntFittingRange(-1, 17) == i6);
    try testing.expect(IntFittingRange(-1, 4095) == i13);
    try testing.expect(IntFittingRange(-4096, 4095) == i13);
    try testing.expect(IntFittingRange(-1, 4096) == i14);
    try testing.expect(IntFittingRange(-4097, 4095) == i14);
    try testing.expect(IntFittingRange(-1, 4097) == i14);
    try testing.expect(IntFittingRange(-1, 123456789123456798123456789) == i88);
    try testing.expect(IntFittingRange(-1, 123456789123456798123456789123456789123456798123456789) == i178);
}

test "overflow functions" {
    try testOverflow();
    try comptime testOverflow();
}

fn testOverflow() !void {
    try testing.expect((mul(i32, 3, 4) catch unreachable) == 12);
    try testing.expect((add(i32, 3, 4) catch unreachable) == 7);
    try testing.expect((sub(i32, 3, 4) catch unreachable) == -1);
    try testing.expect((shlExact(i32, 0b11, 4) catch unreachable) == 0b110000);
}

/// Divide numerator by denominator, rounding toward zero. Returns an
/// error on overflow or when denominator is zero.
pub fn divTrunc(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (@typeInfo(T) == .Int and @typeInfo(T).Int.signedness == .signed and numerator == minInt(T) and denominator == -1) return error.Overflow;
    return @divTrunc(numerator, denominator);
}

test divTrunc {
    try testDivTrunc();
    try comptime testDivTrunc();
}
fn testDivTrunc() !void {
    try testing.expect((divTrunc(i32, 5, 3) catch unreachable) == 1);
    try testing.expect((divTrunc(i32, -5, 3) catch unreachable) == -1);
    try testing.expectError(error.DivisionByZero, divTrunc(i8, -5, 0));
    try testing.expectError(error.Overflow, divTrunc(i8, -128, -1));

    try testing.expect((divTrunc(f32, 5.0, 3.0) catch unreachable) == 1.0);
    try testing.expect((divTrunc(f32, -5.0, 3.0) catch unreachable) == -1.0);
}

/// Divide numerator by denominator, rounding toward negative
/// infinity. Returns an error on overflow or when denominator is
/// zero.
pub fn divFloor(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (@typeInfo(T) == .Int and @typeInfo(T).Int.signedness == .signed and numerator == minInt(T) and denominator == -1) return error.Overflow;
    return @divFloor(numerator, denominator);
}

test divFloor {
    try testDivFloor();
    try comptime testDivFloor();
}
fn testDivFloor() !void {
    try testing.expect((divFloor(i32, 5, 3) catch unreachable) == 1);
    try testing.expect((divFloor(i32, -5, 3) catch unreachable) == -2);
    try testing.expectError(error.DivisionByZero, divFloor(i8, -5, 0));
    try testing.expectError(error.Overflow, divFloor(i8, -128, -1));

    try testing.expect((divFloor(f32, 5.0, 3.0) catch unreachable) == 1.0);
    try testing.expect((divFloor(f32, -5.0, 3.0) catch unreachable) == -2.0);
}

/// Divide numerator by denominator, rounding toward positive
/// infinity. Returns an error on overflow or when denominator is
/// zero.
pub fn divCeil(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    const info = @typeInfo(T);
    switch (info) {
        .ComptimeFloat, .Float => return @ceil(numerator / denominator),
        .ComptimeInt, .Int => {
            if (numerator < 0 and denominator < 0) {
                if (info == .Int and numerator == minInt(T) and denominator == -1)
                    return error.Overflow;
                return @divFloor(numerator + 1, denominator) + 1;
            }
            if (numerator > 0 and denominator > 0)
                return @divFloor(numerator - 1, denominator) + 1;
            return @divTrunc(numerator, denominator);
        },
        else => @compileError("divCeil unsupported on " ++ @typeName(T)),
    }
}

test divCeil {
    try testDivCeil();
    try comptime testDivCeil();
}
fn testDivCeil() !void {
    try testing.expectEqual(@as(i32, 2), divCeil(i32, 5, 3) catch unreachable);
    try testing.expectEqual(@as(i32, -1), divCeil(i32, -5, 3) catch unreachable);
    try testing.expectEqual(@as(i32, -1), divCeil(i32, 5, -3) catch unreachable);
    try testing.expectEqual(@as(i32, 2), divCeil(i32, -5, -3) catch unreachable);
    try testing.expectEqual(@as(i32, 0), divCeil(i32, 0, 5) catch unreachable);
    try testing.expectEqual(@as(u32, 0), divCeil(u32, 0, 5) catch unreachable);
    try testing.expectError(error.DivisionByZero, divCeil(i8, -5, 0));
    try testing.expectError(error.Overflow, divCeil(i8, -128, -1));

    try testing.expectEqual(@as(f32, 0.0), divCeil(f32, 0.0, 5.0) catch unreachable);
    try testing.expectEqual(@as(f32, 2.0), divCeil(f32, 5.0, 3.0) catch unreachable);
    try testing.expectEqual(@as(f32, -1.0), divCeil(f32, -5.0, 3.0) catch unreachable);
    try testing.expectEqual(@as(f32, -1.0), divCeil(f32, 5.0, -3.0) catch unreachable);
    try testing.expectEqual(@as(f32, 2.0), divCeil(f32, -5.0, -3.0) catch unreachable);

    try testing.expectEqual(6, divCeil(comptime_int, 23, 4) catch unreachable);
    try testing.expectEqual(-5, divCeil(comptime_int, -23, 4) catch unreachable);
    try testing.expectEqual(-5, divCeil(comptime_int, 23, -4) catch unreachable);
    try testing.expectEqual(6, divCeil(comptime_int, -23, -4) catch unreachable);
    try testing.expectError(error.DivisionByZero, divCeil(comptime_int, 23, 0));

    try testing.expectEqual(6.0, divCeil(comptime_float, 23.0, 4.0) catch unreachable);
    try testing.expectEqual(-5.0, divCeil(comptime_float, -23.0, 4.0) catch unreachable);
    try testing.expectEqual(-5.0, divCeil(comptime_float, 23.0, -4.0) catch unreachable);
    try testing.expectEqual(6.0, divCeil(comptime_float, -23.0, -4.0) catch unreachable);
    try testing.expectError(error.DivisionByZero, divCeil(comptime_float, 23.0, 0.0));
}

/// Divide numerator by denominator. Return an error if quotient is
/// not an integer, denominator is zero, or on overflow.
pub fn divExact(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (@typeInfo(T) == .Int and @typeInfo(T).Int.signedness == .signed and numerator == minInt(T) and denominator == -1) return error.Overflow;
    const result = @divTrunc(numerator, denominator);
    if (result * denominator != numerator) return error.UnexpectedRemainder;
    return result;
}

test divExact {
    try testDivExact();
    try comptime testDivExact();
}
fn testDivExact() !void {
    try testing.expect((divExact(i32, 10, 5) catch unreachable) == 2);
    try testing.expect((divExact(i32, -10, 5) catch unreachable) == -2);
    try testing.expectError(error.DivisionByZero, divExact(i8, -5, 0));
    try testing.expectError(error.Overflow, divExact(i8, -128, -1));
    try testing.expectError(error.UnexpectedRemainder, divExact(i32, 5, 2));

    try testing.expect((divExact(f32, 10.0, 5.0) catch unreachable) == 2.0);
    try testing.expect((divExact(f32, -10.0, 5.0) catch unreachable) == -2.0);
    try testing.expectError(error.UnexpectedRemainder, divExact(f32, 5.0, 2.0));
}

/// Returns numerator modulo denominator, or an error if denominator is
/// zero or negative. Negative numerators never result in negative
/// return values.
pub fn mod(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (denominator < 0) return error.NegativeDenominator;
    return @mod(numerator, denominator);
}

test mod {
    try testMod();
    try comptime testMod();
}
fn testMod() !void {
    try testing.expect((mod(i32, -5, 3) catch unreachable) == 1);
    try testing.expect((mod(i32, 5, 3) catch unreachable) == 2);
    try testing.expectError(error.NegativeDenominator, mod(i32, 10, -1));
    try testing.expectError(error.DivisionByZero, mod(i32, 10, 0));

    try testing.expect((mod(f32, -5, 3) catch unreachable) == 1);
    try testing.expect((mod(f32, 5, 3) catch unreachable) == 2);
    try testing.expectError(error.NegativeDenominator, mod(f32, 10, -1));
    try testing.expectError(error.DivisionByZero, mod(f32, 10, 0));
}

/// Returns the remainder when numerator is divided by denominator, or
/// an error if denominator is zero or negative. Negative numerators
/// can give negative results.
pub fn rem(comptime T: type, numerator: T, denominator: T) !T {
    @setRuntimeSafety(false);
    if (denominator == 0) return error.DivisionByZero;
    if (denominator < 0) return error.NegativeDenominator;
    return @rem(numerator, denominator);
}

test rem {
    try testRem();
    try comptime testRem();
}
fn testRem() !void {
    try testing.expect((rem(i32, -5, 3) catch unreachable) == -2);
    try testing.expect((rem(i32, 5, 3) catch unreachable) == 2);
    try testing.expectError(error.NegativeDenominator, rem(i32, 10, -1));
    try testing.expectError(error.DivisionByZero, rem(i32, 10, 0));

    try testing.expect((rem(f32, -5, 3) catch unreachable) == -2);
    try testing.expect((rem(f32, 5, 3) catch unreachable) == 2);
    try testing.expectError(error.NegativeDenominator, rem(f32, 10, -1));
    try testing.expectError(error.DivisionByZero, rem(f32, 10, 0));
}

/// Returns the negation of the integer parameter.
/// Result is a signed integer.
pub fn negateCast(x: anytype) !std.meta.Int(.signed, @bitSizeOf(@TypeOf(x))) {
    if (@typeInfo(@TypeOf(x)).Int.signedness == .signed) return negate(x);

    const int = std.meta.Int(.signed, @bitSizeOf(@TypeOf(x)));
    if (x > -minInt(int)) return error.Overflow;

    if (x == -minInt(int)) return minInt(int);

    return -@as(int, @intCast(x));
}

test negateCast {
    try testing.expect((negateCast(@as(u32, 999)) catch unreachable) == -999);
    try testing.expect(@TypeOf(negateCast(@as(u32, 999)) catch unreachable) == i32);

    try testing.expect((negateCast(@as(u32, -minInt(i32))) catch unreachable) == minInt(i32));
    try testing.expect(@TypeOf(negateCast(@as(u32, -minInt(i32))) catch unreachable) == i32);

    try testing.expectError(error.Overflow, negateCast(@as(u32, maxInt(i32) + 10)));
}

/// Cast an integer to a different integer type. If the value doesn't fit,
/// return null.
pub fn cast(comptime T: type, x: anytype) ?T {
    comptime assert(@typeInfo(T) == .Int); // must pass an integer
    const is_comptime = @TypeOf(x) == comptime_int;
    comptime assert(is_comptime or @typeInfo(@TypeOf(x)) == .Int); // must pass an integer
    if ((is_comptime or maxInt(@TypeOf(x)) > maxInt(T)) and x > maxInt(T)) {
        return null;
    } else if ((is_comptime or minInt(@TypeOf(x)) < minInt(T)) and x < minInt(T)) {
        return null;
    } else {
        return @as(T, @intCast(x));
    }
}

test cast {
    try testing.expect(cast(u8, 300) == null);
    try testing.expect(cast(u8, @as(u32, 300)) == null);
    try testing.expect(cast(i8, -200) == null);
    try testing.expect(cast(i8, @as(i32, -200)) == null);
    try testing.expect(cast(u8, -1) == null);
    try testing.expect(cast(u8, @as(i8, -1)) == null);
    try testing.expect(cast(u64, -1) == null);
    try testing.expect(cast(u64, @as(i8, -1)) == null);

    try testing.expect(cast(u8, 255).? == @as(u8, 255));
    try testing.expect(cast(u8, @as(u32, 255)).? == @as(u8, 255));
    try testing.expect(@TypeOf(cast(u8, 255).?) == u8);
    try testing.expect(@TypeOf(cast(u8, @as(u32, 255)).?) == u8);
}

pub const AlignCastError = error{UnalignedMemory};

fn AlignCastResult(comptime alignment: u29, comptime Ptr: type) type {
    var ptr_info = @typeInfo(Ptr);
    ptr_info.Pointer.alignment = alignment;
    return @Type(ptr_info);
}

/// Align cast a pointer but return an error if it's the wrong alignment
pub fn alignCast(comptime alignment: u29, ptr: anytype) AlignCastError!AlignCastResult(alignment, @TypeOf(ptr)) {
    const addr = @intFromPtr(ptr);
    if (addr % alignment != 0) {
        return error.UnalignedMemory;
    }
    return @alignCast(ptr);
}

/// Asserts `int > 0`.
pub fn isPowerOfTwo(int: anytype) bool {
    assert(int > 0);
    return (int & (int - 1)) == 0;
}

test isPowerOfTwo {
    try testing.expect(isPowerOfTwo(@as(u8, 1)));
    try testing.expect(isPowerOfTwo(2));
    try testing.expect(!isPowerOfTwo(@as(i16, 3)));
    try testing.expect(isPowerOfTwo(4));
    try testing.expect(!isPowerOfTwo(@as(u32, 31)));
    try testing.expect(isPowerOfTwo(32));
    try testing.expect(!isPowerOfTwo(@as(i64, 63)));
    try testing.expect(isPowerOfTwo(128));
    try testing.expect(isPowerOfTwo(@as(u128, 256)));
}

/// Aligns the given integer type bit width to a width divisible by 8.
pub fn ByteAlignedInt(comptime T: type) type {
    const info = @typeInfo(T).Int;
    const bits = (info.bits + 7) / 8 * 8;
    const extended_type = std.meta.Int(info.signedness, bits);
    return extended_type;
}

test ByteAlignedInt {
    try testing.expect(ByteAlignedInt(u0) == u0);
    try testing.expect(ByteAlignedInt(i0) == i0);
    try testing.expect(ByteAlignedInt(u3) == u8);
    try testing.expect(ByteAlignedInt(u8) == u8);
    try testing.expect(ByteAlignedInt(i111) == i112);
    try testing.expect(ByteAlignedInt(u129) == u136);
}

/// Rounds the given floating point number to an integer, away from zero.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @round
pub inline fn round(value: anytype) @TypeOf(value) {
    return @round(value);
}

/// Rounds the given floating point number to an integer, towards zero.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @trunc
pub inline fn trunc(value: anytype) @TypeOf(value) {
    return @trunc(value);
}

/// Returns the largest integral value not greater than the given floating point number.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @floor
pub inline fn floor(value: anytype) @TypeOf(value) {
    return @floor(value);
}

/// Returns the nearest power of two less than or equal to value, or
/// zero if value is less than or equal to zero.
pub fn floorPowerOfTwo(comptime T: type, value: T) T {
    const uT = std.meta.Int(.unsigned, @typeInfo(T).Int.bits);
    if (value <= 0) return 0;
    return @as(T, 1) << log2_int(uT, @as(uT, @intCast(value)));
}

test floorPowerOfTwo {
    try testFloorPowerOfTwo();
    try comptime testFloorPowerOfTwo();
}

fn testFloorPowerOfTwo() !void {
    try testing.expect(floorPowerOfTwo(u32, 63) == 32);
    try testing.expect(floorPowerOfTwo(u32, 64) == 64);
    try testing.expect(floorPowerOfTwo(u32, 65) == 64);
    try testing.expect(floorPowerOfTwo(u32, 0) == 0);
    try testing.expect(floorPowerOfTwo(u4, 7) == 4);
    try testing.expect(floorPowerOfTwo(u4, 8) == 8);
    try testing.expect(floorPowerOfTwo(u4, 9) == 8);
    try testing.expect(floorPowerOfTwo(u4, 0) == 0);
    try testing.expect(floorPowerOfTwo(i4, 7) == 4);
    try testing.expect(floorPowerOfTwo(i4, -8) == 0);
    try testing.expect(floorPowerOfTwo(i4, -1) == 0);
    try testing.expect(floorPowerOfTwo(i4, 0) == 0);
}

/// Returns the smallest integral value not less than the given floating point number.
/// Uses a dedicated hardware instruction when available.
/// This is the same as calling the builtin @ceil
pub inline fn ceil(value: anytype) @TypeOf(value) {
    return @ceil(value);
}

/// Returns the next power of two (if the value is not already a power of two).
/// Only unsigned integers can be used. Zero is not an allowed input.
/// Result is a type with 1 more bit than the input type.
pub fn ceilPowerOfTwoPromote(comptime T: type, value: T) std.meta.Int(@typeInfo(T).Int.signedness, @typeInfo(T).Int.bits + 1) {
    comptime assert(@typeInfo(T) == .Int);
    comptime assert(@typeInfo(T).Int.signedness == .unsigned);
    assert(value != 0);
    const PromotedType = std.meta.Int(@typeInfo(T).Int.signedness, @typeInfo(T).Int.bits + 1);
    const ShiftType = std.math.Log2Int(PromotedType);
    return @as(PromotedType, 1) << @as(ShiftType, @intCast(@typeInfo(T).Int.bits - @clz(value - 1)));
}

/// Returns the next power of two (if the value is not already a power of two).
/// Only unsigned integers can be used. Zero is not an allowed input.
/// If the value doesn't fit, returns an error.
pub fn ceilPowerOfTwo(comptime T: type, value: T) (error{Overflow}!T) {
    comptime assert(@typeInfo(T) == .Int);
    const info = @typeInfo(T).Int;
    comptime assert(info.signedness == .unsigned);
    const PromotedType = std.meta.Int(info.signedness, info.bits + 1);
    const overflowBit = @as(PromotedType, 1) << info.bits;
    const x = ceilPowerOfTwoPromote(T, value);
    if (overflowBit & x != 0) {
        return error.Overflow;
    }
    return @as(T, @intCast(x));
}

/// Returns the next power of two (if the value is not already a power
/// of two). Only unsigned integers can be used. Zero is not an
/// allowed input. Asserts that the value fits.
pub fn ceilPowerOfTwoAssert(comptime T: type, value: T) T {
    return ceilPowerOfTwo(T, value) catch unreachable;
}

test ceilPowerOfTwoPromote {
    try testCeilPowerOfTwoPromote();
    try comptime testCeilPowerOfTwoPromote();
}

fn testCeilPowerOfTwoPromote() !void {
    try testing.expectEqual(@as(u33, 1), ceilPowerOfTwoPromote(u32, 1));
    try testing.expectEqual(@as(u33, 2), ceilPowerOfTwoPromote(u32, 2));
    try testing.expectEqual(@as(u33, 64), ceilPowerOfTwoPromote(u32, 63));
    try testing.expectEqual(@as(u33, 64), ceilPowerOfTwoPromote(u32, 64));
    try testing.expectEqual(@as(u33, 128), ceilPowerOfTwoPromote(u32, 65));
    try testing.expectEqual(@as(u6, 8), ceilPowerOfTwoPromote(u5, 7));
    try testing.expectEqual(@as(u6, 8), ceilPowerOfTwoPromote(u5, 8));
    try testing.expectEqual(@as(u6, 16), ceilPowerOfTwoPromote(u5, 9));
    try testing.expectEqual(@as(u5, 16), ceilPowerOfTwoPromote(u4, 9));
}

test ceilPowerOfTwo {
    try testCeilPowerOfTwo();
    try comptime testCeilPowerOfTwo();
}

fn testCeilPowerOfTwo() !void {
    try testing.expectEqual(@as(u32, 1), try ceilPowerOfTwo(u32, 1));
    try testing.expectEqual(@as(u32, 2), try ceilPowerOfTwo(u32, 2));
    try testing.expectEqual(@as(u32, 64), try ceilPowerOfTwo(u32, 63));
    try testing.expectEqual(@as(u32, 64), try ceilPowerOfTwo(u32, 64));
    try testing.expectEqual(@as(u32, 128), try ceilPowerOfTwo(u32, 65));
    try testing.expectEqual(@as(u5, 8), try ceilPowerOfTwo(u5, 7));
    try testing.expectEqual(@as(u5, 8), try ceilPowerOfTwo(u5, 8));
    try testing.expectEqual(@as(u5, 16), try ceilPowerOfTwo(u5, 9));
    try testing.expectError(error.Overflow, ceilPowerOfTwo(u4, 9));
}

/// Return the log base 2 of integer value x, rounding down to the
/// nearest integer.
pub fn log2_int(comptime T: type, x: T) Log2Int(T) {
    if (@typeInfo(T) != .Int or @typeInfo(T).Int.signedness != .unsigned)
        @compileError("log2_int requires an unsigned integer, found " ++ @typeName(T));
    assert(x != 0);
    return @as(Log2Int(T), @intCast(@typeInfo(T).Int.bits - 1 - @clz(x)));
}

/// Return the log base 2 of integer value x, rounding up to the
/// nearest integer.
pub fn log2_int_ceil(comptime T: type, x: T) Log2IntCeil(T) {
    if (@typeInfo(T) != .Int or @typeInfo(T).Int.signedness != .unsigned)
        @compileError("log2_int_ceil requires an unsigned integer, found " ++ @typeName(T));
    assert(x != 0);
    if (x == 1) return 0;
    const log2_val: Log2IntCeil(T) = log2_int(T, x - 1);
    return log2_val + 1;
}

test log2_int_ceil {
    try testing.expect(log2_int_ceil(u32, 1) == 0);
    try testing.expect(log2_int_ceil(u32, 2) == 1);
    try testing.expect(log2_int_ceil(u32, 3) == 2);
    try testing.expect(log2_int_ceil(u32, 4) == 2);
    try testing.expect(log2_int_ceil(u32, 5) == 3);
    try testing.expect(log2_int_ceil(u32, 6) == 3);
    try testing.expect(log2_int_ceil(u32, 7) == 3);
    try testing.expect(log2_int_ceil(u32, 8) == 3);
    try testing.expect(log2_int_ceil(u32, 9) == 4);
    try testing.expect(log2_int_ceil(u32, 10) == 4);
}

/// Cast a value to a different type. If the value doesn't fit in, or
/// can't be perfectly represented by, the new type, it will be
/// converted to the closest possible representation.
pub fn lossyCast(comptime T: type, value: anytype) T {
    switch (@typeInfo(T)) {
        .Float => {
            switch (@typeInfo(@TypeOf(value))) {
                .Int => return @as(T, @floatFromInt(value)),
                .Float => return @as(T, @floatCast(value)),
                .ComptimeInt => return @as(T, value),
                .ComptimeFloat => return @as(T, value),
                else => @compileError("bad type"),
            }
        },
        .Int => {
            switch (@typeInfo(@TypeOf(value))) {
                .Int, .ComptimeInt => {
                    if (value >= maxInt(T)) {
                        return @as(T, maxInt(T));
                    } else if (value <= minInt(T)) {
                        return @as(T, minInt(T));
                    } else {
                        return @as(T, @intCast(value));
                    }
                },
                .Float, .ComptimeFloat => {
                    if (isNan(value)) {
                        return 0;
                    } else if (value >= maxInt(T)) {
                        return @as(T, maxInt(T));
                    } else if (value <= minInt(T)) {
                        return @as(T, minInt(T));
                    } else {
                        return @as(T, @intFromFloat(value));
                    }
                },
                else => @compileError("bad type"),
            }
        },
        else => @compileError("bad result type"),
    }
}

test lossyCast {
    try testing.expect(lossyCast(i16, 70000.0) == @as(i16, 32767));
    try testing.expect(lossyCast(u32, @as(i16, -255)) == @as(u32, 0));
    try testing.expect(lossyCast(i9, @as(u32, 200)) == @as(i9, 200));
    try testing.expect(lossyCast(u32, @as(f32, maxInt(u32))) == maxInt(u32));
    try testing.expect(lossyCast(u32, nan(f32)) == 0);
}

/// Performs linear interpolation between *a* and *b* based on *t*.
/// *t* ranges from 0.0 to 1.0, but may exceed these bounds.
/// Supports floats and vectors of floats.
///
/// This does not guarantee returning *b* if *t* is 1 due to floating-point errors.
/// This is monotonic.
pub fn lerp(a: anytype, b: anytype, t: anytype) @TypeOf(a, b, t) {
    const Type = @TypeOf(a, b, t);
    return @mulAdd(Type, b - a, t, a);
}

test lerp {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/17884
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .fma)) return error.SkipZigTest;

    try testing.expectEqual(@as(f64, 75), lerp(50, 100, 0.5));
    try testing.expectEqual(@as(f32, 43.75), lerp(50, 25, 0.25));
    try testing.expectEqual(@as(f64, -31.25), lerp(-50, 25, 0.25));

    try testing.expectEqual(@as(f64, 30), lerp(10, 20, 2.0));
    try testing.expectEqual(@as(f64, 5), lerp(10, 20, -0.5));

    try testing.expectApproxEqRel(@as(f32, -7.16067345e+03), lerp(-10000.12345, -5000.12345, 0.56789), 1e-19);
    try testing.expectApproxEqRel(@as(f64, 7.010987590521e+62), lerp(0.123456789e-64, 0.123456789e64, 0.56789), 1e-33);

    try testing.expectEqual(@as(f32, 0.0), lerp(@as(f32, 1.0e8), 1.0, 1.0));
    try testing.expectEqual(@as(f64, 0.0), lerp(@as(f64, 1.0e16), 1.0, 1.0));
    try testing.expectEqual(@as(f32, 1.0), lerp(@as(f32, 1.0e7), 1.0, 1.0));
    try testing.expectEqual(@as(f64, 1.0), lerp(@as(f64, 1.0e15), 1.0, 1.0));

    {
        const a: @Vector(3, f32) = @splat(0);
        const b: @Vector(3, f32) = @splat(50);
        const t: @Vector(3, f32) = @splat(0.5);
        try testing.expectEqual(
            @Vector(3, f32){ 25, 25, 25 },
            lerp(a, b, t),
        );
    }
    {
        const a: @Vector(3, f64) = @splat(50);
        const b: @Vector(3, f64) = @splat(100);
        const t: @Vector(3, f64) = @splat(0.5);
        try testing.expectEqual(
            @Vector(3, f64){ 75, 75, 75 },
            lerp(a, b, t),
        );
    }
    {
        const a: @Vector(2, f32) = @splat(40);
        const b: @Vector(2, f32) = @splat(80);
        const t: @Vector(2, f32) = @Vector(2, f32){ 0.25, 0.75 };
        try testing.expectEqual(
            @Vector(2, f32){ 50, 70 },
            lerp(a, b, t),
        );
    }
}

/// Returns the maximum value of integer type T.
pub fn maxInt(comptime T: type) comptime_int {
    const info = @typeInfo(T);
    const bit_count = info.Int.bits;
    if (bit_count == 0) return 0;
    return (1 << (bit_count - @intFromBool(info.Int.signedness == .signed))) - 1;
}

/// Returns the minimum value of integer type T.
pub fn minInt(comptime T: type) comptime_int {
    const info = @typeInfo(T);
    const bit_count = info.Int.bits;
    if (info.Int.signedness == .unsigned) return 0;
    if (bit_count == 0) return 0;
    return -(1 << (bit_count - 1));
}

test maxInt {
    try testing.expect(maxInt(u0) == 0);
    try testing.expect(maxInt(u1) == 1);
    try testing.expect(maxInt(u8) == 255);
    try testing.expect(maxInt(u16) == 65535);
    try testing.expect(maxInt(u32) == 4294967295);
    try testing.expect(maxInt(u64) == 18446744073709551615);
    try testing.expect(maxInt(u128) == 340282366920938463463374607431768211455);

    try testing.expect(maxInt(i0) == 0);
    try testing.expect(maxInt(i1) == 0);
    try testing.expect(maxInt(i8) == 127);
    try testing.expect(maxInt(i16) == 32767);
    try testing.expect(maxInt(i32) == 2147483647);
    try testing.expect(maxInt(i63) == 4611686018427387903);
    try testing.expect(maxInt(i64) == 9223372036854775807);
    try testing.expect(maxInt(i128) == 170141183460469231731687303715884105727);
}

test minInt {
    try testing.expect(minInt(u0) == 0);
    try testing.expect(minInt(u1) == 0);
    try testing.expect(minInt(u8) == 0);
    try testing.expect(minInt(u16) == 0);
    try testing.expect(minInt(u32) == 0);
    try testing.expect(minInt(u63) == 0);
    try testing.expect(minInt(u64) == 0);
    try testing.expect(minInt(u128) == 0);

    try testing.expect(minInt(i0) == 0);
    try testing.expect(minInt(i1) == -1);
    try testing.expect(minInt(i8) == -128);
    try testing.expect(minInt(i16) == -32768);
    try testing.expect(minInt(i32) == -2147483648);
    try testing.expect(minInt(i63) == -4611686018427387904);
    try testing.expect(minInt(i64) == -9223372036854775808);
    try testing.expect(minInt(i128) == -170141183460469231731687303715884105728);
}

test "max value type" {
    const x: u32 = maxInt(i32);
    try testing.expect(x == 2147483647);
}

/// Multiply a and b. Return type is wide enough to guarantee no
/// overflow.
pub fn mulWide(comptime T: type, a: T, b: T) std.meta.Int(
    @typeInfo(T).Int.signedness,
    @typeInfo(T).Int.bits * 2,
) {
    const ResultInt = std.meta.Int(
        @typeInfo(T).Int.signedness,
        @typeInfo(T).Int.bits * 2,
    );
    return @as(ResultInt, a) * @as(ResultInt, b);
}

test mulWide {
    try testing.expect(mulWide(u8, 5, 5) == 25);
    try testing.expect(mulWide(i8, 5, -5) == -25);
    try testing.expect(mulWide(u8, 100, 100) == 10000);
}

/// See also `CompareOperator`.
pub const Order = enum {
    /// Greater than (`>`)
    gt,

    /// Less than (`<`)
    lt,

    /// Equal (`==`)
    eq,

    pub fn invert(self: Order) Order {
        return switch (self) {
            .lt => .gt,
            .eq => .eq,
            .gt => .lt,
        };
    }

    test invert {
        try testing.expect(Order.invert(order(0, 0)) == .eq);
        try testing.expect(Order.invert(order(1, 0)) == .lt);
        try testing.expect(Order.invert(order(-1, 0)) == .gt);
    }

    pub fn differ(self: Order) ?Order {
        return if (self != .eq) self else null;
    }

    test differ {
        const neg: i32 = -1;
        const zero: i32 = 0;
        const pos: i32 = 1;
        try testing.expect(order(zero, neg).differ() orelse
            order(pos, zero) == .gt);
        try testing.expect(order(zero, zero).differ() orelse
            order(zero, zero) == .eq);
        try testing.expect(order(pos, pos).differ() orelse
            order(neg, zero) == .lt);
        try testing.expect(order(zero, zero).differ() orelse
            order(pos, neg).differ() orelse
            order(neg, zero) == .gt);
        try testing.expect(order(pos, pos).differ() orelse
            order(pos, pos).differ() orelse
            order(neg, neg) == .eq);
        try testing.expect(order(zero, pos).differ() orelse
            order(neg, pos).differ() orelse
            order(pos, neg) == .lt);
    }

    pub fn compare(self: Order, op: CompareOperator) bool {
        return switch (self) {
            .lt => switch (op) {
                .lt => true,
                .lte => true,
                .eq => false,
                .gte => false,
                .gt => false,
                .neq => true,
            },
            .eq => switch (op) {
                .lt => false,
                .lte => true,
                .eq => true,
                .gte => true,
                .gt => false,
                .neq => false,
            },
            .gt => switch (op) {
                .lt => false,
                .lte => false,
                .eq => false,
                .gte => true,
                .gt => true,
                .neq => true,
            },
        };
    }

    // https://github.com/ziglang/zig/issues/19295
    test "compare" {
        try testing.expect(order(-1, 0).compare(.lt));
        try testing.expect(order(-1, 0).compare(.lte));
        try testing.expect(order(0, 0).compare(.lte));
        try testing.expect(order(0, 0).compare(.eq));
        try testing.expect(order(0, 0).compare(.gte));
        try testing.expect(order(1, 0).compare(.gte));
        try testing.expect(order(1, 0).compare(.gt));
        try testing.expect(order(1, 0).compare(.neq));
    }
};

/// Given two numbers, this function returns the order they are with respect to each other.
pub fn order(a: anytype, b: anytype) Order {
    if (a == b) {
        return .eq;
    } else if (a < b) {
        return .lt;
    } else if (a > b) {
        return .gt;
    } else {
        unreachable;
    }
}

/// See also `Order`.
pub const CompareOperator = enum {
    /// Less than (`<`)
    lt,
    /// Less than or equal (`<=`)
    lte,
    /// Equal (`==`)
    eq,
    /// Greater than or equal (`>=`)
    gte,
    /// Greater than (`>`)
    gt,
    /// Not equal (`!=`)
    neq,

    /// Reverse the direction of the comparison.
    /// Use when swapping the left and right hand operands.
    pub fn reverse(op: CompareOperator) CompareOperator {
        return switch (op) {
            .lt => .gt,
            .lte => .gte,
            .gt => .lt,
            .gte => .lte,
            .eq => .eq,
            .neq => .neq,
        };
    }

    test reverse {
        inline for (@typeInfo(CompareOperator).Enum.fields) |op_field| {
            const op = @as(CompareOperator, @enumFromInt(op_field.value));
            try testing.expect(compare(2, op, 3) == compare(3, op.reverse(), 2));
            try testing.expect(compare(3, op, 3) == compare(3, op.reverse(), 3));
            try testing.expect(compare(4, op, 3) == compare(3, op.reverse(), 4));
        }
    }
};

/// This function does the same thing as comparison operators, however the
/// operator is a runtime-known enum value. Works on any operands that
/// support comparison operators.
pub fn compare(a: anytype, op: CompareOperator, b: anytype) bool {
    return switch (op) {
        .lt => a < b,
        .lte => a <= b,
        .eq => a == b,
        .neq => a != b,
        .gt => a > b,
        .gte => a >= b,
    };
}

test compare {
    try testing.expect(compare(@as(i8, -1), .lt, @as(u8, 255)));
    try testing.expect(compare(@as(i8, 2), .gt, @as(u8, 1)));
    try testing.expect(!compare(@as(i8, -1), .gte, @as(u8, 255)));
    try testing.expect(compare(@as(u8, 255), .gt, @as(i8, -1)));
    try testing.expect(!compare(@as(u8, 255), .lte, @as(i8, -1)));
    try testing.expect(compare(@as(i8, -1), .lt, @as(u9, 255)));
    try testing.expect(!compare(@as(i8, -1), .gte, @as(u9, 255)));
    try testing.expect(compare(@as(u9, 255), .gt, @as(i8, -1)));
    try testing.expect(!compare(@as(u9, 255), .lte, @as(i8, -1)));
    try testing.expect(compare(@as(i9, -1), .lt, @as(u8, 255)));
    try testing.expect(!compare(@as(i9, -1), .gte, @as(u8, 255)));
    try testing.expect(compare(@as(u8, 255), .gt, @as(i9, -1)));
    try testing.expect(!compare(@as(u8, 255), .lte, @as(i9, -1)));
    try testing.expect(compare(@as(u8, 1), .lt, @as(u8, 2)));
    try testing.expect(@as(u8, @bitCast(@as(i8, -1))) == @as(u8, 255));
    try testing.expect(!compare(@as(u8, 255), .eq, @as(i8, -1)));
    try testing.expect(compare(@as(u8, 1), .eq, @as(u8, 1)));
}

test order {
    try testing.expect(order(0, 0) == .eq);
    try testing.expect(order(1, 0) == .gt);
    try testing.expect(order(-1, 0) == .lt);
}

/// Returns a mask of all ones if value is true,
/// and a mask of all zeroes if value is false.
/// Compiles to one instruction for register sized integers.
pub inline fn boolMask(comptime MaskInt: type, value: bool) MaskInt {
    if (@typeInfo(MaskInt) != .Int)
        @compileError("boolMask requires an integer mask type.");

    if (MaskInt == u0 or MaskInt == i0)
        @compileError("boolMask cannot convert to u0 or i0, they are too small.");

    // The u1 and i1 cases tend to overflow,
    // so we special case them here.
    if (MaskInt == u1) return @intFromBool(value);
    if (MaskInt == i1) {
        // The @as here is a workaround for #7950
        return @as(i1, @bitCast(@as(u1, @intFromBool(value))));
    }

    return -%@as(MaskInt, @intCast(@intFromBool(value)));
}

test boolMask {
    const runTest = struct {
        fn runTest() !void {
            try testing.expectEqual(@as(u1, 0), boolMask(u1, false));
            try testing.expectEqual(@as(u1, 1), boolMask(u1, true));

            try testing.expectEqual(@as(i1, 0), boolMask(i1, false));
            try testing.expectEqual(@as(i1, -1), boolMask(i1, true));

            try testing.expectEqual(@as(u13, 0), boolMask(u13, false));
            try testing.expectEqual(@as(u13, 0x1FFF), boolMask(u13, true));

            try testing.expectEqual(@as(i13, 0), boolMask(i13, false));
            try testing.expectEqual(@as(i13, -1), boolMask(i13, true));

            try testing.expectEqual(@as(u32, 0), boolMask(u32, false));
            try testing.expectEqual(@as(u32, 0xFFFF_FFFF), boolMask(u32, true));

            try testing.expectEqual(@as(i32, 0), boolMask(i32, false));
            try testing.expectEqual(@as(i32, -1), boolMask(i32, true));
        }
    }.runTest;
    try runTest();
    try comptime runTest();
}

/// Return the mod of `num` with the smallest integer type
pub fn comptimeMod(num: anytype, comptime denom: comptime_int) IntFittingRange(0, denom - 1) {
    return @as(IntFittingRange(0, denom - 1), @intCast(@mod(num, denom)));
}

pub const F80 = struct {
    fraction: u64,
    exp: u16,
};

pub fn make_f80(repr: F80) f80 {
    const int = (@as(u80, repr.exp) << 64) | repr.fraction;
    return @as(f80, @bitCast(int));
}

pub fn break_f80(x: f80) F80 {
    const int = @as(u80, @bitCast(x));
    return .{
        .fraction = @as(u64, @truncate(int)),
        .exp = @as(u16, @truncate(int >> 64)),
    };
}

/// Returns -1, 0, or 1.
/// Supports integer and float types and vectors of integer and float types.
/// Unsigned integer types will always return 0 or 1.
/// Branchless.
pub inline fn sign(i: anytype) @TypeOf(i) {
    const T = @TypeOf(i);
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => @as(T, @intFromBool(i > 0)) - @as(T, @intFromBool(i < 0)),
        .Float, .ComptimeFloat => @as(T, @floatFromInt(@intFromBool(i > 0))) - @as(T, @floatFromInt(@intFromBool(i < 0))),
        .Vector => |vinfo| blk: {
            switch (@typeInfo(vinfo.child)) {
                .Int, .Float => {
                    const zero: T = @splat(0);
                    const one: T = @splat(1);
                    break :blk @select(vinfo.child, i > zero, one, zero) - @select(vinfo.child, i < zero, one, zero);
                },
                else => @compileError("Expected vector of ints or floats, found " ++ @typeName(T)),
            }
        },
        else => @compileError("Expected an int, float or vector of one, found " ++ @typeName(T)),
    };
}

fn testSign() !void {
    // each of the following blocks checks the inputs
    // 2, -2, 0, { 2, -2, 0 } provide expected output
    // 1, -1, 0, { 1, -1, 0 } for the given T
    // (negative values omitted for unsigned types)
    {
        const T = i8;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, -1), sign(@as(T, -2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(3, T){ 1, -1, 0 }, sign(@Vector(3, T){ 2, -2, 0 }));
    }
    {
        const T = i32;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, -1), sign(@as(T, -2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(3, T){ 1, -1, 0 }, sign(@Vector(3, T){ 2, -2, 0 }));
    }
    {
        const T = i64;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, -1), sign(@as(T, -2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(3, T){ 1, -1, 0 }, sign(@Vector(3, T){ 2, -2, 0 }));
    }
    {
        const T = u8;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(2, T){ 1, 0 }, sign(@Vector(2, T){ 2, 0 }));
    }
    {
        const T = u32;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(2, T){ 1, 0 }, sign(@Vector(2, T){ 2, 0 }));
    }
    {
        const T = u64;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(2, T){ 1, 0 }, sign(@Vector(2, T){ 2, 0 }));
    }
    {
        const T = f16;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, -1), sign(@as(T, -2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(3, T){ 1, -1, 0 }, sign(@Vector(3, T){ 2, -2, 0 }));
    }
    {
        const T = f32;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, -1), sign(@as(T, -2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(3, T){ 1, -1, 0 }, sign(@Vector(3, T){ 2, -2, 0 }));
    }
    {
        const T = f64;
        try std.testing.expectEqual(@as(T, 1), sign(@as(T, 2)));
        try std.testing.expectEqual(@as(T, -1), sign(@as(T, -2)));
        try std.testing.expectEqual(@as(T, 0), sign(@as(T, 0)));
        try std.testing.expectEqual(@Vector(3, T){ 1, -1, 0 }, sign(@Vector(3, T){ 2, -2, 0 }));
    }

    // comptime_int
    try std.testing.expectEqual(-1, sign(-10));
    try std.testing.expectEqual(1, sign(10));
    try std.testing.expectEqual(0, sign(0));
    // comptime_float
    try std.testing.expectEqual(-1.0, sign(-10.0));
    try std.testing.expectEqual(1.0, sign(10.0));
    try std.testing.expectEqual(0.0, sign(0.0));
}

test sign {
    if (builtin.zig_backend == .stage2_llvm) {
        // https://github.com/ziglang/zig/issues/12012
        return error.SkipZigTest;
    }
    try testSign();
    try comptime testSign();
}

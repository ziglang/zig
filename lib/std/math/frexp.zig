const std = @import("../std.zig");
const math = std.math;
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

pub fn Frexp(comptime T: type) type {
    return struct {
        significand: T,
        exponent: i32,
    };
}

/// Breaks x into a normalized fraction and an integral power of two.
/// f == frac * 2^exp, with |frac| in the interval [0.5, 1).
///
/// Special Cases:
///  - frexp(+-0)   = +-0, 0
///  - frexp(+-inf) = +-inf, 0
///  - frexp(nan)   = nan, undefined
pub fn frexp(x: anytype) Frexp(@TypeOf(x)) {
    const T: type = @TypeOf(x);
    const info = @typeInfo(T);
    comptime assert(info == .float or info == .comptime_float);

    const bits: comptime_int = if (info == .float) info.float.bits else 128;
    const Int: type = std.meta.Int(.unsigned, bits);

    const exp_bits: comptime_int = math.floatExponentBits(T);
    const mant_bits: comptime_int = math.floatMantissaBits(T);
    const frac_bits: comptime_int = math.floatFractionalBits(T);
    const exp_min: comptime_int = math.floatExponentMin(T);

    const ExpInt: type = std.meta.Int(.unsigned, exp_bits);
    const MantInt: type = std.meta.Int(.unsigned, mant_bits);
    const FracInt: type = std.meta.Int(.unsigned, frac_bits);

    const unreal_exponent: comptime_int = (1 << exp_bits) - 1;
    const bias: comptime_int = (1 << (exp_bits - 1)) - 2;
    const exp_mask: comptime_int = unreal_exponent << mant_bits;
    const zero_exponent: comptime_int = bias << mant_bits;
    const sign_mask: comptime_int = 1 << (bits - 1);
    const not_exp: comptime_int = ~@as(Int, exp_mask);
    const ones_place: comptime_int = mant_bits - frac_bits;
    const extra_denorm_shift: comptime_int = 1 - ones_place;

    var result: Frexp(T) = undefined;
    var v: Int = if (info == .float) @bitCast(x) else @bitCast(@as(f128, x));

    const m: MantInt = @truncate(v);
    const e: ExpInt = @truncate(v >> mant_bits);

    switch (e) {
        0 => {
            if (m != 0) {
                // subnormal
                const offset = @clz(m);
                const shift = offset + extra_denorm_shift;

                v &= sign_mask;
                v |= zero_exponent;
                v |= math.shl(MantInt, m, shift);

                result.exponent = exp_min - @as(i32, offset) + ones_place;
            } else {
                // +-0 = (+-0, 0)
                result.exponent = 0;
            }
        },
        unreal_exponent => {
            // +-nan -> {+-nan, undefined}
            result.exponent = undefined;

            // +-inf -> {+-inf, 0}
            if (@as(FracInt, @truncate(v)) == 0)
                result.exponent = 0;
        },
        else => {
            // normal
            v &= not_exp;
            v |= zero_exponent;
            result.exponent = @as(i32, e) - bias;
        },
    }

    result.significand = if (info == .float) @bitCast(v) else @as(f128, @bitCast(v));
    return result;
}

/// Generate a namespace of tests for frexp on values of the given type
fn FrexpTests(comptime Float: type) type {
    return struct {
        const T = Float;
        test "normal" {
            const epsilon = 1e-6;

            const r1 = frexp(@as(T, 1.3));
            try expectApproxEqAbs(0.65, r1.significand, epsilon);
            try expectEqual(1, r1.exponent);

            const r2 = frexp(@as(T, 78.0234));
            try expectApproxEqAbs(0.609558, r2.significand, epsilon);
            try expectEqual(7, r2.exponent);

            const r3 = frexp(@as(T, -1234.5678));
            try expectEqual(11, r3.exponent);
            try expectApproxEqAbs(-0.602816, r3.significand, epsilon);
        }
        test "max" {
            const exponent = math.floatExponentMax(T) + 1;
            const significand = 1.0 - math.floatEps(T) / 2.0;
            const r: Frexp(T) = frexp(math.floatMax(T));
            try expectEqual(exponent, r.exponent);
            try expectEqual(significand, r.significand);
        }
        test "min" {
            const exponent = math.floatExponentMin(T) + 1;
            const r: Frexp(T) = frexp(math.floatMin(T));
            try expectEqual(exponent, r.exponent);
            try expectEqual(0.5, r.significand);
        }
        test "subnormal" {
            const normal_min_exponent = math.floatExponentMin(T) + 1;
            const exponent = normal_min_exponent - math.floatFractionalBits(T);
            const r: Frexp(T) = frexp(math.floatTrueMin(T));
            try expectEqual(exponent, r.exponent);
            try expectEqual(0.5, r.significand);
        }
        test "zero" {
            const r1 = frexp(@as(T, 0.0));
            try expectEqual(0, r1.exponent);
            try expect(math.isPositiveZero(r1.significand));

            const r2 = frexp(@as(T, -0.0));
            try expectEqual(0, r2.exponent);
            try expect(math.isNegativeZero(r2.significand));
        }
        test "inf" {
            if (T == comptime_float) return;
            var r: Frexp(T) = undefined;

            r = frexp(math.inf(T));
            try expectEqual(0, r.exponent);
            try expect(math.isPositiveInf(r.significand));

            r = frexp(-math.inf(T));
            try expectEqual(0, r.exponent);
            try expect(math.isNegativeInf(r.significand));
        }
        test "nan" {
            if (T == comptime_float) return;
            const r: Frexp(T) = frexp(math.nan(T));
            try expect(math.isNan(r.significand));
        }
    };
}

// Generate tests for each floating point type
comptime {
    for ([_]type{ f16, f32, f64, f80, f128, comptime_float }) |T| {
        _ = FrexpTests(T);
    }
}

test frexp {
    @setEvalBranchQuota(1_500);

    inline for ([_]type{ f16, f32, f64, f80, f128, comptime_float }) |T| {
        const max_exponent = math.floatExponentMax(T) + 1;
        const min_exponent = math.floatExponentMin(T) + 1;
        const truemin_exponent = min_exponent - math.floatFractionalBits(T);

        // basic usage
        // value -> {significand, exponent},
        // value == significand * (2 ^ exponent)
        const x1 = 1234.5678;
        const result1 = frexp(x1);
        try expectEqual(11, result1.exponent);
        try expectApproxEqAbs(0.602816, result1.significand, 1e-6);
        try expectEqual(x1, math.ldexp(result1.significand, result1.exponent));

        // float maximum
        const x2 = math.floatMax(T);
        const result2 = frexp(x2);
        try expectEqual(max_exponent, result2.exponent);
        try expectEqual(1.0 - math.floatEps(T) / 2.0, result2.significand);
        try expectEqual(x2, math.ldexp(result2.significand, result2.exponent));

        // float minimum
        const x3 = math.floatMin(T);
        const result3 = frexp(x3);
        try expectEqual(min_exponent, result3.exponent);
        try expectEqual(0.5, result3.significand);
        try expectEqual(x3, math.ldexp(result3.significand, result3.exponent));

        // float true minimum
        // subnormal -> {normal, exponent}
        const x4 = math.floatTrueMin(T);
        const result4 = frexp(x4);
        try expectEqual(truemin_exponent, result4.exponent);
        try expectEqual(0.5, result4.significand);
        try expectEqual(x4, math.ldexp(result4.significand, result4.exponent));

        // zero -> {zero, zero} (+)
        const result5 = frexp(@as(T, 0.0));
        try expectEqual(0, result5.exponent);
        try expect(math.isPositiveZero(result5.significand));

        // zero -> {zero, zero} (-)
        const result6 = frexp(@as(T, -0.0));
        try expectEqual(0, result6.exponent);
        try expect(math.isNegativeZero(result6.significand));

        if (T == comptime_float) return;

        // infinity -> {infinity, zero} (+)
        var result = frexp(math.inf(T));
        try expectEqual(0, result.exponent);
        try expect(math.isPositiveInf(result.significand));

        // infinity -> {infinity, zero} (-)
        result = frexp(-math.inf(T));
        try expectEqual(0, result.exponent);
        try expect(math.isNegativeInf(result.significand));

        // nan -> {nan, undefined}
        result = frexp(math.nan(T));
        try expect(math.isNan(result.significand));
    }
}

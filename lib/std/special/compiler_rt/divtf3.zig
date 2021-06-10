// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const builtin = @import("builtin");

const normalize = @import("divdf3.zig").normalize;
const wideMultiply = @import("divdf3.zig").wideMultiply;

pub fn __divtf3(a: f128, b: f128) callconv(.C) f128 {
    @setRuntimeSafety(builtin.is_test);
    const Z = std.meta.Int(.unsigned, 128);

    const significandBits = std.math.floatMantissaBits(f128);
    const exponentBits = std.math.floatExponentBits(f128);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const implicitBit = (@as(Z, 1) << significandBits);
    const quietBit = implicitBit >> 1;
    const significandMask = implicitBit - 1;

    const absMask = signBit - 1;
    const exponentMask = absMask ^ significandMask;
    const qnanRep = exponentMask | quietBit;
    const infRep = @bitCast(Z, std.math.inf(f128));

    const aExponent = @truncate(u32, (@bitCast(Z, a) >> significandBits) & maxExponent);
    const bExponent = @truncate(u32, (@bitCast(Z, b) >> significandBits) & maxExponent);
    const quotientSign: Z = (@bitCast(Z, a) ^ @bitCast(Z, b)) & signBit;

    var aSignificand: Z = @bitCast(Z, a) & significandMask;
    var bSignificand: Z = @bitCast(Z, b) & significandMask;
    var scale: i32 = 0;

    // Detect if a or b is zero, denormal, infinity, or NaN.
    if (aExponent -% 1 >= maxExponent -% 1 or bExponent -% 1 >= maxExponent -% 1) {
        const aAbs: Z = @bitCast(Z, a) & absMask;
        const bAbs: Z = @bitCast(Z, b) & absMask;

        // NaN / anything = qNaN
        if (aAbs > infRep) return @bitCast(f128, @bitCast(Z, a) | quietBit);
        // anything / NaN = qNaN
        if (bAbs > infRep) return @bitCast(f128, @bitCast(Z, b) | quietBit);

        if (aAbs == infRep) {
            // infinity / infinity = NaN
            if (bAbs == infRep) {
                return @bitCast(f128, qnanRep);
            }
            // infinity / anything else = +/- infinity
            else {
                return @bitCast(f128, aAbs | quotientSign);
            }
        }

        // anything else / infinity = +/- 0
        if (bAbs == infRep) return @bitCast(f128, quotientSign);

        if (aAbs == 0) {
            // zero / zero = NaN
            if (bAbs == 0) {
                return @bitCast(f128, qnanRep);
            }
            // zero / anything else = +/- zero
            else {
                return @bitCast(f128, quotientSign);
            }
        }
        // anything else / zero = +/- infinity
        if (bAbs == 0) return @bitCast(f128, infRep | quotientSign);

        // one or both of a or b is denormal, the other (if applicable) is a
        // normal number.  Renormalize one or both of a and b, and set scale to
        // include the necessary exponent adjustment.
        if (aAbs < implicitBit) scale +%= normalize(f128, &aSignificand);
        if (bAbs < implicitBit) scale -%= normalize(f128, &bSignificand);
    }

    // Set the implicit significand bit.  If we fell through from the
    // denormal path it was already set by normalize( ), but setting it twice
    // won't hurt anything.
    aSignificand |= implicitBit;
    bSignificand |= implicitBit;
    var quotientExponent: i32 = @bitCast(i32, aExponent -% bExponent) +% scale;

    // Align the significand of b as a Q63 fixed-point number in the range
    // [1, 2.0) and get a Q64 approximate reciprocal using a small minimax
    // polynomial approximation: reciprocal = 3/4 + 1/sqrt(2) - b/2.  This
    // is accurate to about 3.5 binary digits.
    const q63b = @truncate(u64, bSignificand >> 49);
    var recip64 = @as(u64, 0x7504f333F9DE6484) -% q63b;
    // 0x7504f333F9DE6484 / 2^64 + 1 = 3/4 + 1/sqrt(2)

    // Now refine the reciprocal estimate using a Newton-Raphson iteration:
    //
    //     x1 = x0 * (2 - x0 * b)
    //
    // This doubles the number of correct binary digits in the approximation
    // with each iteration.
    var correction64: u64 = undefined;
    correction64 = @truncate(u64, ~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(u64, @as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(u64, ~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(u64, @as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(u64, ~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(u64, @as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(u64, ~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(u64, @as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(u64, ~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(u64, @as(u128, recip64) *% correction64 >> 63);

    // The reciprocal may have overflowed to zero if the upper half of b is
    // exactly 1.0.  This would sabatoge the full-width final stage of the
    // computation that follows, so we adjust the reciprocal down by one bit.
    recip64 -%= 1;

    // We need to perform one more iteration to get us to 112 binary digits;
    // The last iteration needs to happen with extra precision.
    const q127blo: u64 = @truncate(u64, bSignificand << 15);
    var correction: u128 = undefined;
    var reciprocal: u128 = undefined;

    // NOTE: This operation is equivalent to __multi3, which is not implemented
    //       in some architechure
    var r64q63: u128 = undefined;
    var r64q127: u128 = undefined;
    var r64cH: u128 = undefined;
    var r64cL: u128 = undefined;
    var dummy: u128 = undefined;
    wideMultiply(u128, recip64, q63b, &dummy, &r64q63);
    wideMultiply(u128, recip64, q127blo, &dummy, &r64q127);

    correction = -%(r64q63 + (r64q127 >> 64));

    const cHi = @truncate(u64, correction >> 64);
    const cLo = @truncate(u64, correction);

    wideMultiply(u128, recip64, cHi, &dummy, &r64cH);
    wideMultiply(u128, recip64, cLo, &dummy, &r64cL);

    reciprocal = r64cH + (r64cL >> 64);

    // Adjust the final 128-bit reciprocal estimate downward to ensure that it
    // is strictly smaller than the infinitely precise exact reciprocal. Because
    // the computation of the Newton-Raphson step is truncating at every step,
    // this adjustment is small; most of the work is already done.
    reciprocal -%= 2;

    // The numerical reciprocal is accurate to within 2^-112, lies in the
    // interval [0.5, 1.0), and is strictly smaller than the true reciprocal
    // of b.  Multiplying a by this reciprocal thus gives a numerical q = a/b
    // in Q127 with the following properties:
    //
    //    1. q < a/b
    //    2. q is in the interval [0.5, 2.0)
    //    3. The error in q is bounded away from 2^-113 (actually, we have a
    //       couple of bits to spare, but this is all we need).

    // We need a 128 x 128 multiply high to compute q.
    var quotient: u128 = undefined;
    var quotientLo: u128 = undefined;
    wideMultiply(u128, aSignificand << 2, reciprocal, &quotient, &quotientLo);

    // Two cases: quotient is in [0.5, 1.0) or quotient is in [1.0, 2.0).
    // In either case, we are going to compute a residual of the form
    //
    //     r = a - q*b
    //
    // We know from the construction of q that r satisfies:
    //
    //     0 <= r < ulp(q)*b
    //
    // If r is greater than 1/2 ulp(q)*b, then q rounds up.  Otherwise, we
    // already have the correct result.  The exact halfway case cannot occur.
    // We also take this time to right shift quotient if it falls in the [1,2)
    // range and adjust the exponent accordingly.
    var residual: u128 = undefined;
    var qb: u128 = undefined;

    if (quotient < (implicitBit << 1)) {
        wideMultiply(u128, quotient, bSignificand, &dummy, &qb);
        residual = (aSignificand << 113) -% qb;
        quotientExponent -%= 1;
    } else {
        quotient >>= 1;
        wideMultiply(u128, quotient, bSignificand, &dummy, &qb);
        residual = (aSignificand << 112) -% qb;
    }

    const writtenExponent = quotientExponent +% exponentBias;

    if (writtenExponent >= maxExponent) {
        // If we have overflowed the exponent, return infinity.
        return @bitCast(f128, infRep | quotientSign);
    } else if (writtenExponent < 1) {
        if (writtenExponent == 0) {
            // Check whether the rounded result is normal.
            const round = @boolToInt((residual << 1) > bSignificand);
            // Clear the implicit bit.
            var absResult = quotient & significandMask;
            // Round.
            absResult += round;
            if ((absResult & ~significandMask) > 0) {
                // The rounded result is normal; return it.
                return @bitCast(f128, absResult | quotientSign);
            }
        }
        // Flush denormals to zero.  In the future, it would be nice to add
        // code to round them correctly.
        return @bitCast(f128, quotientSign);
    } else {
        const round = @boolToInt((residual << 1) >= bSignificand);
        // Clear the implicit bit
        var absResult = quotient & significandMask;
        // Insert the exponent
        absResult |= @intCast(Z, writtenExponent) << significandBits;
        // Round
        absResult +%= round;
        // Insert the sign and return
        return @bitCast(f128, absResult | quotientSign);
    }
}

test "import divtf3" {
    _ = @import("divtf3_test.zig");
}

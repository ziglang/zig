// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/divsf3.c

const std = @import("std");
const builtin = @import("builtin");

pub fn __divsf3(a: f32, b: f32) callconv(.C) f32 {
    @setRuntimeSafety(builtin.is_test);
    const Z = std.meta.Int(false, 32);

    const significandBits = std.math.floatMantissaBits(f32);
    const exponentBits = std.math.floatExponentBits(f32);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const implicitBit = (@as(Z, 1) << significandBits);
    const quietBit = implicitBit >> 1;
    const significandMask = implicitBit - 1;

    const absMask = signBit - 1;
    const exponentMask = absMask ^ significandMask;
    const qnanRep = exponentMask | quietBit;
    const infRep = @bitCast(Z, std.math.inf(f32));

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
        if (aAbs > infRep) return @bitCast(f32, @bitCast(Z, a) | quietBit);
        // anything / NaN = qNaN
        if (bAbs > infRep) return @bitCast(f32, @bitCast(Z, b) | quietBit);

        if (aAbs == infRep) {
            // infinity / infinity = NaN
            if (bAbs == infRep) {
                return @bitCast(f32, qnanRep);
            }
            // infinity / anything else = +/- infinity
            else {
                return @bitCast(f32, aAbs | quotientSign);
            }
        }

        // anything else / infinity = +/- 0
        if (bAbs == infRep) return @bitCast(f32, quotientSign);

        if (aAbs == 0) {
            // zero / zero = NaN
            if (bAbs == 0) {
                return @bitCast(f32, qnanRep);
            }
            // zero / anything else = +/- zero
            else {
                return @bitCast(f32, quotientSign);
            }
        }
        // anything else / zero = +/- infinity
        if (bAbs == 0) return @bitCast(f32, infRep | quotientSign);

        // one or both of a or b is denormal, the other (if applicable) is a
        // normal number.  Renormalize one or both of a and b, and set scale to
        // include the necessary exponent adjustment.
        if (aAbs < implicitBit) scale +%= normalize(f32, &aSignificand);
        if (bAbs < implicitBit) scale -%= normalize(f32, &bSignificand);
    }

    // Or in the implicit significand bit.  (If we fell through from the
    // denormal path it was already set by normalize( ), but setting it twice
    // won't hurt anything.)
    aSignificand |= implicitBit;
    bSignificand |= implicitBit;
    var quotientExponent: i32 = @bitCast(i32, aExponent -% bExponent) +% scale;

    // Align the significand of b as a Q31 fixed-point number in the range
    // [1, 2.0) and get a Q32 approximate reciprocal using a small minimax
    // polynomial approximation: reciprocal = 3/4 + 1/sqrt(2) - b/2.  This
    // is accurate to about 3.5 binary digits.
    const q31b = bSignificand << 8;
    var reciprocal = @as(u32, 0x7504f333) -% q31b;

    // Now refine the reciprocal estimate using a Newton-Raphson iteration:
    //
    //     x1 = x0 * (2 - x0 * b)
    //
    // This doubles the number of correct binary digits in the approximation
    // with each iteration, so after three iterations, we have about 28 binary
    // digits of accuracy.
    var correction: u32 = undefined;
    correction = @truncate(u32, ~(@as(u64, reciprocal) *% q31b >> 32) +% 1);
    reciprocal = @truncate(u32, @as(u64, reciprocal) *% correction >> 31);
    correction = @truncate(u32, ~(@as(u64, reciprocal) *% q31b >> 32) +% 1);
    reciprocal = @truncate(u32, @as(u64, reciprocal) *% correction >> 31);
    correction = @truncate(u32, ~(@as(u64, reciprocal) *% q31b >> 32) +% 1);
    reciprocal = @truncate(u32, @as(u64, reciprocal) *% correction >> 31);

    // Exhaustive testing shows that the error in reciprocal after three steps
    // is in the interval [-0x1.f58108p-31, 0x1.d0e48cp-29], in line with our
    // expectations.  We bump the reciprocal by a tiny value to force the error
    // to be strictly positive (in the range [0x1.4fdfp-37,0x1.287246p-29], to
    // be specific).  This also causes 1/1 to give a sensible approximation
    // instead of zero (due to overflow).
    reciprocal -%= 2;

    // The numerical reciprocal is accurate to within 2^-28, lies in the
    // interval [0x1.000000eep-1, 0x1.fffffffcp-1], and is strictly smaller
    // than the true reciprocal of b.  Multiplying a by this reciprocal thus
    // gives a numerical q = a/b in Q24 with the following properties:
    //
    //    1. q < a/b
    //    2. q is in the interval [0x1.000000eep-1, 0x1.fffffffcp0)
    //    3. the error in q is at most 2^-24 + 2^-27 -- the 2^24 term comes
    //       from the fact that we truncate the product, and the 2^27 term
    //       is the error in the reciprocal of b scaled by the maximum
    //       possible value of a.  As a consequence of this error bound,
    //       either q or nextafter(q) is the correctly rounded
    var quotient: Z = @truncate(u32, @as(u64, reciprocal) *% (aSignificand << 1) >> 32);

    // Two cases: quotient is in [0.5, 1.0) or quotient is in [1.0, 2.0).
    // In either case, we are going to compute a residual of the form
    //
    //     r = a - q*b
    //
    // We know from the construction of q that r satisfies:
    //
    //     0 <= r < ulp(q)*b
    //
    // if r is greater than 1/2 ulp(q)*b, then q rounds up.  Otherwise, we
    // already have the correct result.  The exact halfway case cannot occur.
    // We also take this time to right shift quotient if it falls in the [1,2)
    // range and adjust the exponent accordingly.
    var residual: Z = undefined;
    if (quotient < (implicitBit << 1)) {
        residual = (aSignificand << 24) -% quotient *% bSignificand;
        quotientExponent -%= 1;
    } else {
        quotient >>= 1;
        residual = (aSignificand << 23) -% quotient *% bSignificand;
    }

    const writtenExponent = quotientExponent +% exponentBias;

    if (writtenExponent >= maxExponent) {
        // If we have overflowed the exponent, return infinity.
        return @bitCast(f32, infRep | quotientSign);
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
                return @bitCast(f32, absResult | quotientSign);
            }
        }
        // Flush denormals to zero.  In the future, it would be nice to add
        // code to round them correctly.
        return @bitCast(f32, quotientSign);
    } else {
        const round = @boolToInt((residual << 1) > bSignificand);
        // Clear the implicit bit
        var absResult = quotient & significandMask;
        // Insert the exponent
        absResult |= @bitCast(Z, writtenExponent) << significandBits;
        // Round
        absResult +%= round;
        // Insert the sign and return
        return @bitCast(f32, absResult | quotientSign);
    }
}

fn normalize(comptime T: type, significand: *std.meta.Int(false, @typeInfo(T).Float.bits)) i32 {
    @setRuntimeSafety(builtin.is_test);
    const Z = std.meta.Int(false, @typeInfo(T).Float.bits);
    const significandBits = std.math.floatMantissaBits(T);
    const implicitBit = @as(Z, 1) << significandBits;

    const shift = @clz(Z, significand.*) - @clz(Z, implicitBit);
    significand.* <<= @intCast(std.math.Log2Int(Z), shift);
    return 1 - shift;
}

pub fn __aeabi_fdiv(a: f32, b: f32) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __divsf3, .{ a, b });
}

test "import divsf3" {
    _ = @import("divsf3_test.zig");
}

//! Ported from:
//!
//! https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/divdf3.c

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const common = @import("common.zig");

const normalize = common.normalize;
const wideMultiply = common.wideMultiply;

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_ddiv, .{ .name = "__aeabi_ddiv", .linkage = common.linkage, .visibility = common.visibility });
    } else {
        @export(&__divdf3, .{ .name = "__divdf3", .linkage = common.linkage, .visibility = common.visibility });
    }
}

pub fn __divdf3(a: f64, b: f64) callconv(.C) f64 {
    return div(a, b);
}

fn __aeabi_ddiv(a: f64, b: f64) callconv(.AAPCS) f64 {
    return div(a, b);
}

inline fn div(a: f64, b: f64) f64 {
    const Z = std.meta.Int(.unsigned, 64);
    const SignedZ = std.meta.Int(.signed, 64);

    const significandBits = std.math.floatMantissaBits(f64);
    const exponentBits = std.math.floatExponentBits(f64);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const implicitBit = (@as(Z, 1) << significandBits);
    const quietBit = implicitBit >> 1;
    const significandMask = implicitBit - 1;

    const absMask = signBit - 1;
    const exponentMask = absMask ^ significandMask;
    const qnanRep = exponentMask | quietBit;
    const infRep = @as(Z, @bitCast(std.math.inf(f64)));

    const aExponent: u32 = @truncate((@as(Z, @bitCast(a)) >> significandBits) & maxExponent);
    const bExponent: u32 = @truncate((@as(Z, @bitCast(b)) >> significandBits) & maxExponent);
    const quotientSign: Z = (@as(Z, @bitCast(a)) ^ @as(Z, @bitCast(b))) & signBit;

    var aSignificand: Z = @as(Z, @bitCast(a)) & significandMask;
    var bSignificand: Z = @as(Z, @bitCast(b)) & significandMask;
    var scale: i32 = 0;

    // Detect if a or b is zero, denormal, infinity, or NaN.
    if (aExponent -% 1 >= maxExponent - 1 or bExponent -% 1 >= maxExponent - 1) {
        const aAbs: Z = @as(Z, @bitCast(a)) & absMask;
        const bAbs: Z = @as(Z, @bitCast(b)) & absMask;

        // NaN / anything = qNaN
        if (aAbs > infRep) return @bitCast(@as(Z, @bitCast(a)) | quietBit);
        // anything / NaN = qNaN
        if (bAbs > infRep) return @bitCast(@as(Z, @bitCast(b)) | quietBit);

        if (aAbs == infRep) {
            // infinity / infinity = NaN
            if (bAbs == infRep) {
                return @bitCast(qnanRep);
            }
            // infinity / anything else = +/- infinity
            else {
                return @bitCast(aAbs | quotientSign);
            }
        }

        // anything else / infinity = +/- 0
        if (bAbs == infRep) return @bitCast(quotientSign);

        if (aAbs == 0) {
            // zero / zero = NaN
            if (bAbs == 0) {
                return @bitCast(qnanRep);
            }
            // zero / anything else = +/- zero
            else {
                return @bitCast(quotientSign);
            }
        }
        // anything else / zero = +/- infinity
        if (bAbs == 0) return @bitCast(infRep | quotientSign);

        // one or both of a or b is denormal, the other (if applicable) is a
        // normal number.  Renormalize one or both of a and b, and set scale to
        // include the necessary exponent adjustment.
        if (aAbs < implicitBit) scale +%= normalize(f64, &aSignificand);
        if (bAbs < implicitBit) scale -%= normalize(f64, &bSignificand);
    }

    // Or in the implicit significand bit.  (If we fell through from the
    // denormal path it was already set by normalize( ), but setting it twice
    // won't hurt anything.)
    aSignificand |= implicitBit;
    bSignificand |= implicitBit;
    var quotientExponent: i32 = @as(i32, @bitCast(aExponent -% bExponent)) +% scale;

    // Align the significand of b as a Q31 fixed-point number in the range
    // [1, 2.0) and get a Q32 approximate reciprocal using a small minimax
    // polynomial approximation: reciprocal = 3/4 + 1/sqrt(2) - b/2.  This
    // is accurate to about 3.5 binary digits.
    const q31b: u32 = @truncate(bSignificand >> 21);
    var recip32 = @as(u32, 0x7504f333) -% q31b;

    // Now refine the reciprocal estimate using a Newton-Raphson iteration:
    //
    //     x1 = x0 * (2 - x0 * b)
    //
    // This doubles the number of correct binary digits in the approximation
    // with each iteration, so after three iterations, we have about 28 binary
    // digits of accuracy.
    var correction32: u32 = undefined;
    correction32 = @truncate(~(@as(u64, recip32) *% q31b >> 32) +% 1);
    recip32 = @truncate(@as(u64, recip32) *% correction32 >> 31);
    correction32 = @truncate(~(@as(u64, recip32) *% q31b >> 32) +% 1);
    recip32 = @truncate(@as(u64, recip32) *% correction32 >> 31);
    correction32 = @truncate(~(@as(u64, recip32) *% q31b >> 32) +% 1);
    recip32 = @truncate(@as(u64, recip32) *% correction32 >> 31);

    // recip32 might have overflowed to exactly zero in the preceding
    // computation if the high word of b is exactly 1.0.  This would sabotage
    // the full-width final stage of the computation that follows, so we adjust
    // recip32 downward by one bit.
    recip32 -%= 1;

    // We need to perform one more iteration to get us to 56 binary digits;
    // The last iteration needs to happen with extra precision.
    const q63blo: u32 = @truncate(bSignificand << 11);
    var correction: u64 = undefined;
    var reciprocal: u64 = undefined;
    correction = ~(@as(u64, recip32) *% q31b +% (@as(u64, recip32) *% q63blo >> 32)) +% 1;
    const cHi: u32 = @truncate(correction >> 32);
    const cLo: u32 = @truncate(correction);
    reciprocal = @as(u64, recip32) *% cHi +% (@as(u64, recip32) *% cLo >> 32);

    // We already adjusted the 32-bit estimate, now we need to adjust the final
    // 64-bit reciprocal estimate downward to ensure that it is strictly smaller
    // than the infinitely precise exact reciprocal.  Because the computation
    // of the Newton-Raphson step is truncating at every step, this adjustment
    // is small; most of the work is already done.
    reciprocal -%= 2;

    // The numerical reciprocal is accurate to within 2^-56, lies in the
    // interval [0.5, 1.0), and is strictly smaller than the true reciprocal
    // of b.  Multiplying a by this reciprocal thus gives a numerical q = a/b
    // in Q53 with the following properties:
    //
    //    1. q < a/b
    //    2. q is in the interval [0.5, 2.0)
    //    3. the error in q is bounded away from 2^-53 (actually, we have a
    //       couple of bits to spare, but this is all we need).

    // We need a 64 x 64 multiply high to compute q, which isn't a basic
    // operation in C, so we need to be a little bit fussy.
    var quotient: Z = undefined;
    var quotientLo: Z = undefined;
    wideMultiply(Z, aSignificand << 2, reciprocal, &quotient, &quotientLo);

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
        residual = (aSignificand << 53) -% quotient *% bSignificand;
        quotientExponent -%= 1;
    } else {
        quotient >>= 1;
        residual = (aSignificand << 52) -% quotient *% bSignificand;
    }

    const writtenExponent = quotientExponent +% exponentBias;

    if (writtenExponent >= maxExponent) {
        // If we have overflowed the exponent, return infinity.
        return @bitCast(infRep | quotientSign);
    } else if (writtenExponent < 1) {
        if (writtenExponent == 0) {
            // Check whether the rounded result is normal.
            const round = @intFromBool((residual << 1) > bSignificand);
            // Clear the implicit bit.
            var absResult = quotient & significandMask;
            // Round.
            absResult += round;
            if ((absResult & ~significandMask) != 0) {
                // The rounded result is normal; return it.
                return @bitCast(absResult | quotientSign);
            }
        }
        // Flush denormals to zero.  In the future, it would be nice to add
        // code to round them correctly.
        return @bitCast(quotientSign);
    } else {
        const round = @intFromBool((residual << 1) > bSignificand);
        // Clear the implicit bit
        var absResult = quotient & significandMask;
        // Insert the exponent
        absResult |= @as(Z, @bitCast(@as(SignedZ, writtenExponent))) << significandBits;
        // Round
        absResult +%= round;
        // Insert the sign and return
        return @bitCast(absResult | quotientSign);
    }
}

test {
    _ = @import("divdf3_test.zig");
}

const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;

const common = @import("common.zig");
const normalize = common.normalize;
const wideMultiply = common.wideMultiply;

pub const panic = common.panic;

comptime {
    @export(__divxf3, .{ .name = "__divxf3", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __divxf3(a: f80, b: f80) callconv(.C) f80 {
    const T = f80;
    const Z = std.meta.Int(.unsigned, @bitSizeOf(T));

    const significandBits = std.math.floatMantissaBits(T);
    const fractionalBits = std.math.floatFractionalBits(T);
    const exponentBits = std.math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const integerBit = (@as(Z, 1) << fractionalBits);
    const quietBit = integerBit >> 1;
    const significandMask = (@as(Z, 1) << significandBits) - 1;

    const absMask = signBit - 1;
    const qnanRep = @as(Z, @bitCast(std.math.nan(T))) | quietBit;
    const infRep: Z = @bitCast(std.math.inf(T));

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
        if (aAbs < integerBit) scale +%= normalize(T, &aSignificand);
        if (bAbs < integerBit) scale -%= normalize(T, &bSignificand);
    }
    var quotientExponent: i32 = @as(i32, @bitCast(aExponent -% bExponent)) +% scale;

    // Align the significand of b as a Q63 fixed-point number in the range
    // [1, 2.0) and get a Q64 approximate reciprocal using a small minimax
    // polynomial approximation: reciprocal = 3/4 + 1/sqrt(2) - b/2.  This
    // is accurate to about 3.5 binary digits.
    const q63b: u64 = @intCast(bSignificand);
    var recip64 = @as(u64, 0x7504f333F9DE6484) -% q63b;
    // 0x7504f333F9DE6484 / 2^64 + 1 = 3/4 + 1/sqrt(2)

    // Now refine the reciprocal estimate using a Newton-Raphson iteration:
    //
    //     x1 = x0 * (2 - x0 * b)
    //
    // This doubles the number of correct binary digits in the approximation
    // with each iteration.
    var correction64: u64 = undefined;
    correction64 = @truncate(~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(@as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(@as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(@as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(@as(u128, recip64) *% correction64 >> 63);
    correction64 = @truncate(~(@as(u128, recip64) *% q63b >> 64) +% 1);
    recip64 = @truncate(@as(u128, recip64) *% correction64 >> 63);

    // The reciprocal may have overflowed to zero if the upper half of b is
    // exactly 1.0.  This would sabatoge the full-width final stage of the
    // computation that follows, so we adjust the reciprocal down by one bit.
    recip64 -%= 1;

    // We need to perform one more iteration to get us to 112 binary digits;
    // The last iteration needs to happen with extra precision.

    // NOTE: This operation is equivalent to __multi3, which is not implemented
    //       in some architechures
    var reciprocal: u128 = undefined;
    var correction: u128 = undefined;
    var dummy: u128 = undefined;
    wideMultiply(u128, recip64, q63b, &dummy, &correction);

    correction = -%correction;

    const cHi: u64 = @truncate(correction >> 64);
    const cLo: u64 = @truncate(correction);

    var r64cH: u128 = undefined;
    var r64cL: u128 = undefined;
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
    //    3. The error in q is bounded away from 2^-63 (actually, we have
    //       many bits to spare, but this is all we need).

    // We need a 128 x 128 multiply high to compute q.
    var quotient128: u128 = undefined;
    var quotientLo: u128 = undefined;
    wideMultiply(u128, aSignificand << 2, reciprocal, &quotient128, &quotientLo);

    // Two cases: quotient is in [0.5, 1.0) or quotient is in [1.0, 2.0).
    // Right shift the quotient if it falls in the [1,2) range and adjust the
    // exponent accordingly.
    const quotient: u64 = if (quotient128 < (integerBit << 1)) b: {
        quotientExponent -= 1;
        break :b @intCast(quotient128);
    } else @intCast(quotient128 >> 1);

    // We are going to compute a residual of the form
    //
    //     r = a - q*b
    //
    // We know from the construction of q that r satisfies:
    //
    //     0 <= r < ulp(q)*b
    //
    // If r is greater than 1/2 ulp(q)*b, then q rounds up.  Otherwise, we
    // already have the correct result.  The exact halfway case cannot occur.
    const residual: u64 = -%(quotient *% q63b);

    const writtenExponent = quotientExponent + exponentBias;
    if (writtenExponent >= maxExponent) {
        // If we have overflowed the exponent, return infinity.
        return @bitCast(infRep | quotientSign);
    } else if (writtenExponent < 1) {
        if (writtenExponent == 0) {
            // Check whether the rounded result is normal.
            if (residual > (bSignificand >> 1)) { // round
                if (quotient == (integerBit - 1)) // If the rounded result is normal, return it
                    return @bitCast(@as(Z, @bitCast(std.math.floatMin(T))) | quotientSign);
            }
        }
        // Flush denormals to zero.  In the future, it would be nice to add
        // code to round them correctly.
        return @bitCast(quotientSign);
    } else {
        const round = @intFromBool(residual > (bSignificand >> 1));
        // Insert the exponent
        var absResult = quotient | (@as(Z, @intCast(writtenExponent)) << significandBits);
        // Round
        absResult +%= round;
        // Insert the sign and return
        return @bitCast(absResult | quotientSign | integerBit);
    }
}

test {
    _ = @import("divxf3_test.zig");
}

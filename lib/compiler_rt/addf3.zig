const std = @import("std");
const math = std.math;
const common = @import("./common.zig");
const normalize = common.normalize;

/// Ported from:
///
/// https://github.com/llvm/llvm-project/blob/02d85149a05cb1f6dc49f0ba7a2ceca53718ae17/compiler-rt/lib/builtins/fp_add_impl.inc
pub inline fn addf3(comptime T: type, a: T, b: T) T {
    const bits = @typeInfo(T).Float.bits;
    const Z = std.meta.Int(.unsigned, bits);
    const S = std.meta.Int(.unsigned, bits - @clz(@as(Z, bits) - 1));

    const typeWidth = bits;
    const significandBits = math.floatMantissaBits(T);
    const fractionalBits = math.floatFractionalBits(T);
    const exponentBits = math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);

    const integerBit = (@as(Z, 1) << fractionalBits);
    const quietBit = integerBit >> 1;
    const significandMask = (@as(Z, 1) << significandBits) - 1;

    const absMask = signBit - 1;
    const qnanRep = @as(Z, @bitCast(math.nan(T))) | quietBit;

    var aRep = @as(Z, @bitCast(a));
    var bRep = @as(Z, @bitCast(b));
    const aAbs = aRep & absMask;
    const bAbs = bRep & absMask;

    const infRep = @as(Z, @bitCast(math.inf(T)));

    // Detect if a or b is zero, infinity, or NaN.
    if (aAbs -% @as(Z, 1) >= infRep - @as(Z, 1) or
        bAbs -% @as(Z, 1) >= infRep - @as(Z, 1))
    {
        // NaN + anything = qNaN
        if (aAbs > infRep) return @bitCast(@as(Z, @bitCast(a)) | quietBit);
        // anything + NaN = qNaN
        if (bAbs > infRep) return @bitCast(@as(Z, @bitCast(b)) | quietBit);

        if (aAbs == infRep) {
            // +/-infinity + -/+infinity = qNaN
            if ((@as(Z, @bitCast(a)) ^ @as(Z, @bitCast(b))) == signBit) {
                return @bitCast(qnanRep);
            }
            // +/-infinity + anything remaining = +/- infinity
            else {
                return a;
            }
        }

        // anything remaining + +/-infinity = +/-infinity
        if (bAbs == infRep) return b;

        // zero + anything = anything
        if (aAbs == 0) {
            // but we need to get the sign right for zero + zero
            if (bAbs == 0) {
                return @bitCast(@as(Z, @bitCast(a)) & @as(Z, @bitCast(b)));
            } else {
                return b;
            }
        }

        // anything + zero = anything
        if (bAbs == 0) return a;
    }

    // Swap a and b if necessary so that a has the larger absolute value.
    if (bAbs > aAbs) {
        const temp = aRep;
        aRep = bRep;
        bRep = temp;
    }

    // Extract the exponent and significand from the (possibly swapped) a and b.
    var aExponent: i32 = @intCast((aRep >> significandBits) & maxExponent);
    var bExponent: i32 = @intCast((bRep >> significandBits) & maxExponent);
    var aSignificand = aRep & significandMask;
    var bSignificand = bRep & significandMask;

    // Normalize any denormals, and adjust the exponent accordingly.
    if (aExponent == 0) aExponent = normalize(T, &aSignificand);
    if (bExponent == 0) bExponent = normalize(T, &bSignificand);

    // The sign of the result is the sign of the larger operand, a.  If they
    // have opposite signs, we are performing a subtraction; otherwise addition.
    const resultSign = aRep & signBit;
    const subtraction = (aRep ^ bRep) & signBit != 0;

    // Shift the significands to give us round, guard and sticky, and or in the
    // implicit significand bit.  (If we fell through from the denormal path it
    // was already set by normalize( ), but setting it twice won't hurt
    // anything.)
    aSignificand = (aSignificand | integerBit) << 3;
    bSignificand = (bSignificand | integerBit) << 3;

    // Shift the significand of b by the difference in exponents, with a sticky
    // bottom bit to get rounding correct.
    const @"align": u32 = @intCast(aExponent - bExponent);
    if (@"align" != 0) {
        if (@"align" < typeWidth) {
            const sticky = if (bSignificand << @as(S, @intCast(typeWidth - @"align")) != 0) @as(Z, 1) else 0;
            bSignificand = (bSignificand >> @as(S, @truncate(@"align"))) | sticky;
        } else {
            bSignificand = 1; // sticky; b is known to be non-zero.
        }
    }
    if (subtraction) {
        aSignificand -= bSignificand;
        // If a == -b, return +zero.
        if (aSignificand == 0) return @bitCast(@as(Z, 0));

        // If partial cancellation occured, we need to left-shift the result
        // and adjust the exponent:
        if (aSignificand < integerBit << 3) {
            const shift = @as(i32, @intCast(@clz(aSignificand))) - @as(i32, @intCast(@clz(integerBit << 3)));
            aSignificand <<= @as(S, @intCast(shift));
            aExponent -= shift;
        }
    } else { // addition
        aSignificand += bSignificand;

        // If the addition carried up, we need to right-shift the result and
        // adjust the exponent:
        if (aSignificand & (integerBit << 4) != 0) {
            const sticky = aSignificand & 1;
            aSignificand = aSignificand >> 1 | sticky;
            aExponent += 1;
        }
    }

    // If we have overflowed the type, return +/- infinity:
    if (aExponent >= maxExponent) return @bitCast(infRep | resultSign);

    if (aExponent <= 0) {
        // Result is denormal; the exponent and round/sticky bits are zero.
        // All we need to do is shift the significand and apply the correct sign.
        aSignificand >>= @as(S, @intCast(4 - aExponent));
        return @bitCast(resultSign | aSignificand);
    }

    // Low three bits are round, guard, and sticky.
    const roundGuardSticky = aSignificand & 0x7;

    // Shift the significand into place, and mask off the integer bit, if it's implicit.
    var result = (aSignificand >> 3) & significandMask;

    // Insert the exponent and sign.
    result |= @as(Z, @intCast(aExponent)) << significandBits;
    result |= resultSign;

    // Final rounding.  The result may overflow to infinity, but that is the
    // correct result in that case.
    if (roundGuardSticky > 0x4) result += 1;
    if (roundGuardSticky == 0x4) result += result & 1;

    // Restore any explicit integer bit, if it was rounded off
    if (significandBits != fractionalBits) {
        if ((result >> significandBits) != 0) result |= integerBit;
    }

    return @bitCast(result);
}

test {
    _ = @import("addf3_test.zig");
}

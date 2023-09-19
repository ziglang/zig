const std = @import("std");

pub inline fn truncf(comptime dst_t: type, comptime src_t: type, a: src_t) dst_t {
    const src_rep_t = std.meta.Int(.unsigned, @typeInfo(src_t).Float.bits);
    const dst_rep_t = std.meta.Int(.unsigned, @typeInfo(dst_t).Float.bits);
    const srcSigBits = std.math.floatMantissaBits(src_t);
    const dstSigBits = std.math.floatMantissaBits(dst_t);

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const srcBits = @typeInfo(src_t).Float.bits;
    const srcExpBits = srcBits - srcSigBits - 1;
    const srcInfExp = (1 << srcExpBits) - 1;
    const srcExpBias = srcInfExp >> 1;

    const srcMinNormal = 1 << srcSigBits;
    const srcSignificandMask = srcMinNormal - 1;
    const srcInfinity = srcInfExp << srcSigBits;
    const srcSignMask = 1 << (srcSigBits + srcExpBits);
    const srcAbsMask = srcSignMask - 1;
    const roundMask = (1 << (srcSigBits - dstSigBits)) - 1;
    const halfway = 1 << (srcSigBits - dstSigBits - 1);
    const srcQNaN = 1 << (srcSigBits - 1);
    const srcNaNCode = srcQNaN - 1;

    const dstBits = @typeInfo(dst_t).Float.bits;
    const dstExpBits = dstBits - dstSigBits - 1;
    const dstInfExp = (1 << dstExpBits) - 1;
    const dstExpBias = dstInfExp >> 1;

    const underflowExponent = srcExpBias + 1 - dstExpBias;
    const overflowExponent = srcExpBias + dstInfExp - dstExpBias;
    const underflow = underflowExponent << srcSigBits;
    const overflow = overflowExponent << srcSigBits;

    const dstQNaN = 1 << (dstSigBits - 1);
    const dstNaNCode = dstQNaN - 1;

    // Break a into a sign and representation of the absolute value
    const aRep: src_rep_t = @bitCast(a);
    const aAbs: src_rep_t = aRep & srcAbsMask;
    const sign: src_rep_t = aRep & srcSignMask;
    var absResult: dst_rep_t = undefined;

    if (aAbs -% underflow < aAbs -% overflow) {
        // The exponent of a is within the range of normal numbers in the
        // destination format.  We can convert by simply right-shifting with
        // rounding and adjusting the exponent.
        absResult = @truncate(aAbs >> (srcSigBits - dstSigBits));
        absResult -%= @as(dst_rep_t, srcExpBias - dstExpBias) << dstSigBits;

        const roundBits: src_rep_t = aAbs & roundMask;
        if (roundBits > halfway) {
            // Round to nearest
            absResult += 1;
        } else if (roundBits == halfway) {
            // Ties to even
            absResult += absResult & 1;
        }
    } else if (aAbs > srcInfinity) {
        // a is NaN.
        // Conjure the result by beginning with infinity, setting the qNaN
        // bit and inserting the (truncated) trailing NaN field.
        absResult = @as(dst_rep_t, @intCast(dstInfExp)) << dstSigBits;
        absResult |= dstQNaN;
        absResult |= @intCast(((aAbs & srcNaNCode) >> (srcSigBits - dstSigBits)) & dstNaNCode);
    } else if (aAbs >= overflow) {
        // a overflows to infinity.
        absResult = @as(dst_rep_t, @intCast(dstInfExp)) << dstSigBits;
    } else {
        // a underflows on conversion to the destination type or is an exact
        // zero.  The result may be a denormal or zero.  Extract the exponent
        // to get the shift amount for the denormalization.
        const aExp: u32 = @intCast(aAbs >> srcSigBits);
        const shift: u32 = @intCast(srcExpBias - dstExpBias - aExp + 1);

        const significand: src_rep_t = (aRep & srcSignificandMask) | srcMinNormal;

        // Right shift by the denormalization amount with sticky.
        if (shift > srcSigBits) {
            absResult = 0;
        } else {
            const sticky: src_rep_t = @intFromBool(significand << @intCast(srcBits - shift) != 0);
            const denormalizedSignificand: src_rep_t = significand >> @intCast(shift) | sticky;
            absResult = @intCast(denormalizedSignificand >> (srcSigBits - dstSigBits));
            const roundBits: src_rep_t = denormalizedSignificand & roundMask;
            if (roundBits > halfway) {
                // Round to nearest
                absResult += 1;
            } else if (roundBits == halfway) {
                // Ties to even
                absResult += absResult & 1;
            }
        }
    }

    const result: dst_rep_t align(@alignOf(dst_t)) = absResult |
        @as(dst_rep_t, @truncate(sign >> @intCast(srcBits - dstBits)));
    return @bitCast(result);
}

pub inline fn trunc_f80(comptime dst_t: type, a: f80) dst_t {
    const dst_rep_t = std.meta.Int(.unsigned, @typeInfo(dst_t).Float.bits);
    const src_sig_bits = std.math.floatMantissaBits(f80) - 1; // -1 for the integer bit
    const dst_sig_bits = std.math.floatMantissaBits(dst_t);

    const src_exp_bias = 16383;

    const round_mask = (1 << (src_sig_bits - dst_sig_bits)) - 1;
    const halfway = 1 << (src_sig_bits - dst_sig_bits - 1);

    const dst_bits = @typeInfo(dst_t).Float.bits;
    const dst_exp_bits = dst_bits - dst_sig_bits - 1;
    const dst_inf_exp = (1 << dst_exp_bits) - 1;
    const dst_exp_bias = dst_inf_exp >> 1;

    const underflow = src_exp_bias + 1 - dst_exp_bias;
    const overflow = src_exp_bias + dst_inf_exp - dst_exp_bias;

    const dst_qnan = 1 << (dst_sig_bits - 1);
    const dst_nan_mask = dst_qnan - 1;

    // Break a into a sign and representation of the absolute value
    var a_rep = std.math.break_f80(a);
    const sign = a_rep.exp & 0x8000;
    a_rep.exp &= 0x7FFF;
    a_rep.fraction &= 0x7FFFFFFFFFFFFFFF;
    var abs_result: dst_rep_t = undefined;

    if (a_rep.exp -% underflow < a_rep.exp -% overflow) {
        // The exponent of a is within the range of normal numbers in the
        // destination format.  We can convert by simply right-shifting with
        // rounding and adjusting the exponent.
        abs_result = @as(dst_rep_t, a_rep.exp) << dst_sig_bits;
        abs_result |= @truncate(a_rep.fraction >> (src_sig_bits - dst_sig_bits));
        abs_result -%= @as(dst_rep_t, src_exp_bias - dst_exp_bias) << dst_sig_bits;

        const round_bits = a_rep.fraction & round_mask;
        if (round_bits > halfway) {
            // Round to nearest
            abs_result += 1;
        } else if (round_bits == halfway) {
            // Ties to even
            abs_result += abs_result & 1;
        }
    } else if (a_rep.exp == 0x7FFF and a_rep.fraction != 0) {
        // a is NaN.
        // Conjure the result by beginning with infinity, setting the qNaN
        // bit and inserting the (truncated) trailing NaN field.
        abs_result = @as(dst_rep_t, @intCast(dst_inf_exp)) << dst_sig_bits;
        abs_result |= dst_qnan;
        abs_result |= @intCast((a_rep.fraction >> (src_sig_bits - dst_sig_bits)) & dst_nan_mask);
    } else if (a_rep.exp >= overflow) {
        // a overflows to infinity.
        abs_result = @as(dst_rep_t, @intCast(dst_inf_exp)) << dst_sig_bits;
    } else {
        // a underflows on conversion to the destination type or is an exact
        // zero.  The result may be a denormal or zero.  Extract the exponent
        // to get the shift amount for the denormalization.
        const shift = src_exp_bias - dst_exp_bias - a_rep.exp;

        // Right shift by the denormalization amount with sticky.
        if (shift > src_sig_bits) {
            abs_result = 0;
        } else {
            const sticky = @intFromBool(a_rep.fraction << @intCast(shift) != 0);
            const denormalized_significand = a_rep.fraction >> @intCast(shift) | sticky;
            abs_result = @intCast(denormalized_significand >> (src_sig_bits - dst_sig_bits));
            const round_bits = denormalized_significand & round_mask;
            if (round_bits > halfway) {
                // Round to nearest
                abs_result += 1;
            } else if (round_bits == halfway) {
                // Ties to even
                abs_result += abs_result & 1;
            }
        }
    }

    const result align(@alignOf(dst_t)) = abs_result | @as(dst_rep_t, sign) << dst_bits - 16;
    return @bitCast(result);
}

test {
    _ = @import("truncf_test.zig");
}

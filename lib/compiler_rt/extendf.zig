const std = @import("std");

pub inline fn extendf(
    comptime dst_t: type,
    comptime src_t: type,
    a: std.meta.Int(.unsigned, @typeInfo(src_t).float.bits),
) dst_t {
    const src_rep_t = std.meta.Int(.unsigned, @typeInfo(src_t).float.bits);
    const dst_rep_t = std.meta.Int(.unsigned, @typeInfo(dst_t).float.bits);
    const srcSigBits = std.math.floatMantissaBits(src_t);
    const dstSigBits = std.math.floatMantissaBits(dst_t);

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const srcBits = @bitSizeOf(src_t);
    const srcExpBits = srcBits - srcSigBits - 1;
    const srcInfExp = (1 << srcExpBits) - 1;
    const srcExpBias = srcInfExp >> 1;

    const srcMinNormal = 1 << srcSigBits;
    const srcInfinity = srcInfExp << srcSigBits;
    const srcSignMask = 1 << (srcSigBits + srcExpBits);
    const srcAbsMask = srcSignMask - 1;
    const srcQNaN = 1 << (srcSigBits - 1);
    const srcNaNCode = srcQNaN - 1;

    const dstBits = @bitSizeOf(dst_t);
    const dstExpBits = dstBits - dstSigBits - 1;
    const dstInfExp = (1 << dstExpBits) - 1;
    const dstExpBias = dstInfExp >> 1;

    const dstMinNormal: dst_rep_t = @as(dst_rep_t, 1) << dstSigBits;

    // Break a into a sign and representation of the absolute value
    const aRep: src_rep_t = @bitCast(a);
    const aAbs: src_rep_t = aRep & srcAbsMask;
    const sign: src_rep_t = aRep & srcSignMask;
    var absResult: dst_rep_t = undefined;

    if (aAbs -% srcMinNormal < srcInfinity - srcMinNormal) {
        // a is a normal number.
        // Extend to the destination type by shifting the significand and
        // exponent into the proper position and rebiasing the exponent.
        absResult = @as(dst_rep_t, aAbs) << (dstSigBits - srcSigBits);
        absResult += (dstExpBias - srcExpBias) << dstSigBits;
    } else if (aAbs >= srcInfinity) {
        // a is NaN or infinity.
        // Conjure the result by beginning with infinity, then setting the qNaN
        // bit (if needed) and right-aligning the rest of the trailing NaN
        // payload field.
        absResult = dstInfExp << dstSigBits;
        absResult |= @as(dst_rep_t, aAbs & srcQNaN) << (dstSigBits - srcSigBits);
        absResult |= @as(dst_rep_t, aAbs & srcNaNCode) << (dstSigBits - srcSigBits);
    } else if (aAbs != 0) {
        // a is denormal.
        // renormalize the significand and clear the leading bit, then insert
        // the correct adjusted exponent in the destination type.
        const scale: u32 = @clz(aAbs) - @clz(@as(src_rep_t, srcMinNormal));
        absResult = @as(dst_rep_t, aAbs) << @intCast(dstSigBits - srcSigBits + scale);
        absResult ^= dstMinNormal;
        const resultExponent: u32 = dstExpBias - srcExpBias - scale + 1;
        absResult |= @as(dst_rep_t, @intCast(resultExponent)) << dstSigBits;
    } else {
        // a is zero.
        absResult = 0;
    }

    // Apply the signbit to (dst_t)abs(a).
    const result: dst_rep_t align(@alignOf(dst_t)) = absResult | @as(dst_rep_t, sign) << (dstBits - srcBits);
    return @bitCast(result);
}

pub inline fn extend_f80(comptime src_t: type, a: std.meta.Int(.unsigned, @typeInfo(src_t).float.bits)) f80 {
    const src_rep_t = std.meta.Int(.unsigned, @typeInfo(src_t).float.bits);
    const src_sig_bits = std.math.floatMantissaBits(src_t);
    const dst_int_bit = 0x8000000000000000;
    const dst_sig_bits = std.math.floatMantissaBits(f80) - 1; // -1 for the integer bit

    const dst_exp_bias = 16383;

    const src_bits = @bitSizeOf(src_t);
    const src_exp_bits = src_bits - src_sig_bits - 1;
    const src_inf_exp = (1 << src_exp_bits) - 1;
    const src_exp_bias = src_inf_exp >> 1;

    const src_min_normal = 1 << src_sig_bits;
    const src_inf = src_inf_exp << src_sig_bits;
    const src_sign_mask = 1 << (src_sig_bits + src_exp_bits);
    const src_abs_mask = src_sign_mask - 1;
    const src_qnan = 1 << (src_sig_bits - 1);
    const src_nan_code = src_qnan - 1;

    var dst: std.math.F80 = undefined;

    // Break a into a sign and representation of the absolute value
    const a_abs = a & src_abs_mask;
    const sign: u16 = if (a & src_sign_mask != 0) 0x8000 else 0;

    if (a_abs -% src_min_normal < src_inf - src_min_normal) {
        // a is a normal number.
        // Extend to the destination type by shifting the significand and
        // exponent into the proper position and rebiasing the exponent.
        dst.exp = @intCast(a_abs >> src_sig_bits);
        dst.exp += dst_exp_bias - src_exp_bias;
        dst.fraction = @as(u64, a_abs) << (dst_sig_bits - src_sig_bits);
        dst.fraction |= dst_int_bit; // bit 64 is always set for normal numbers
    } else if (a_abs >= src_inf) {
        // a is NaN or infinity.
        // Conjure the result by beginning with infinity, then setting the qNaN
        // bit (if needed) and right-aligning the rest of the trailing NaN
        // payload field.
        dst.exp = 0x7fff;
        dst.fraction = dst_int_bit;
        dst.fraction |= @as(u64, a_abs & src_qnan) << (dst_sig_bits - src_sig_bits);
        dst.fraction |= @as(u64, a_abs & src_nan_code) << (dst_sig_bits - src_sig_bits);
    } else if (a_abs != 0) {
        // a is denormal.
        // renormalize the significand and clear the leading bit, then insert
        // the correct adjusted exponent in the destination type.
        const scale: u16 = @clz(a_abs) - @clz(@as(src_rep_t, src_min_normal));

        dst.fraction = @as(u64, a_abs) << @intCast(dst_sig_bits - src_sig_bits + scale);
        dst.fraction |= dst_int_bit; // bit 64 is always set for normal numbers
        dst.exp = @truncate(a_abs >> @intCast(src_sig_bits - scale));
        dst.exp ^= 1;
        dst.exp |= dst_exp_bias - src_exp_bias - scale + 1;
    } else {
        // a is zero.
        dst.exp = 0;
        dst.fraction = 0;
    }

    dst.exp |= sign;
    return dst.toFloat();
}

test {
    _ = @import("extendf_test.zig");
}

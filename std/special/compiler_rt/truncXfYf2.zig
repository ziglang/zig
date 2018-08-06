const std = @import("std");

pub extern fn __truncsfhf2(a: f32) u16 {
    return @bitCast(u16, truncXfYf2(f16, f32, a));
}

pub extern fn __trunctfsf2(a: f128) f32 {
    return truncXfYf2(f32, f128, a);
}

pub extern fn __trunctfdf2(a: f128) f64 {
    return truncXfYf2(f64, f128, a);
}

inline fn truncXfYf2(comptime dst_t: type, comptime src_t: type, a: src_t) dst_t {
    const src_rep_t = @IntType(false, @typeInfo(src_t).Float.bits);
    const dst_rep_t = @IntType(false, @typeInfo(dst_t).Float.bits);
    const srcSigBits = std.math.floatMantissaBits(src_t);
    const dstSigBits = std.math.floatMantissaBits(dst_t);
    const SrcShift = std.math.Log2Int(src_rep_t);
    const DstShift = std.math.Log2Int(dst_rep_t);

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const srcBits = src_t.bit_count;
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

    const dstBits = dst_t.bit_count;
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
    const aRep: src_rep_t = @bitCast(src_rep_t, a);
    const aAbs: src_rep_t = aRep & srcAbsMask;
    const sign: src_rep_t = aRep & srcSignMask;
    var absResult: dst_rep_t = undefined;

    if (aAbs -% underflow < aAbs -% overflow) {
        // The exponent of a is within the range of normal numbers in the
        // destination format.  We can convert by simply right-shifting with
        // rounding and adjusting the exponent.
        absResult = @truncate(dst_rep_t, aAbs >> (srcSigBits - dstSigBits));
        absResult -%= dst_rep_t(srcExpBias - dstExpBias) << dstSigBits;

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
        absResult = @intCast(dst_rep_t, dstInfExp) << dstSigBits;
        absResult |= dstQNaN;
        absResult |= @intCast(dst_rep_t, ((aAbs & srcNaNCode) >> (srcSigBits - dstSigBits)) & dstNaNCode);
    } else if (aAbs >= overflow) {
        // a overflows to infinity.
        absResult = @intCast(dst_rep_t, dstInfExp) << dstSigBits;
    } else {
        // a underflows on conversion to the destination type or is an exact
        // zero.  The result may be a denormal or zero.  Extract the exponent
        // to get the shift amount for the denormalization.
        const aExp = @intCast(u32, aAbs >> srcSigBits);
        const shift = @intCast(u32, srcExpBias - dstExpBias - aExp + 1);

        const significand: src_rep_t = (aRep & srcSignificandMask) | srcMinNormal;

        // Right shift by the denormalization amount with sticky.
        if (shift > srcSigBits) {
            absResult = 0;
        } else {
            const sticky: src_rep_t = significand << @intCast(SrcShift, srcBits - shift);
            const denormalizedSignificand: src_rep_t = significand >> @intCast(SrcShift, shift) | sticky;
            absResult = @intCast(dst_rep_t, denormalizedSignificand >> (srcSigBits - dstSigBits));
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

    const result: dst_rep_t align(@alignOf(dst_t)) = absResult | @truncate(dst_rep_t, sign >> @intCast(SrcShift, srcBits - dstBits));
    return @bitCast(dst_t, result);
}

test "import truncXfYf2" {
    _ = @import("truncXfYf2_test.zig");
}

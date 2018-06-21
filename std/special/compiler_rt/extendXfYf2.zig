const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;

pub extern fn __extenddftf2(a: f64) f128 {
    return extendXfYf2(f128, f64, a);
}

pub extern fn __extendsftf2(a: f32) f128 {
    return extendXfYf2(f128, f32, a);
}

const CHAR_BIT = 8;

pub fn extendXfYf2(comptime dst_t: type, comptime src_t: type, a: src_t) dst_t {
    const src_rep_t = @IntType(false, @typeInfo(src_t).Float.bits);
    const dst_rep_t = @IntType(false, @typeInfo(dst_t).Float.bits);
    const srcSigBits = std.math.floatMantissaBits(src_t);
    const dstSigBits = std.math.floatMantissaBits(dst_t);
    const SrcShift = std.math.Log2Int(src_rep_t);
    const DstShift = std.math.Log2Int(dst_rep_t);

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const srcBits: i32 = @sizeOf(src_t) * CHAR_BIT;
    const srcExpBits: i32 = srcBits - srcSigBits - 1;
    const srcInfExp: i32 = (1 << srcExpBits) - 1;
    const srcExpBias: i32 = srcInfExp >> 1;

    const srcMinNormal: src_rep_t = src_rep_t(1) << srcSigBits;
    const srcInfinity: src_rep_t = src_rep_t(@bitCast(u32, srcInfExp)) << srcSigBits;
    const srcSignMask: src_rep_t = src_rep_t(1) << @intCast(SrcShift, srcSigBits +% srcExpBits);
    const srcAbsMask: src_rep_t = srcSignMask -% 1;
    const srcQNaN: src_rep_t = src_rep_t(1) << @intCast(SrcShift, srcSigBits -% 1);
    const srcNaNCode: src_rep_t = srcQNaN -% 1;

    const dstBits: i32 = @sizeOf(dst_t) * CHAR_BIT;
    const dstExpBits: i32 = dstBits - dstSigBits - 1;
    const dstInfExp: i32 = (1 << dstExpBits) - 1;
    const dstExpBias: i32 = dstInfExp >> 1;

    const dstMinNormal: dst_rep_t = dst_rep_t(1) << dstSigBits;

    // Break a into a sign and representation of the absolute value
    const aRep: src_rep_t = @bitCast(src_rep_t, a);
    const aAbs: src_rep_t = aRep & srcAbsMask;
    const sign: src_rep_t = aRep & srcSignMask;
    var absResult: dst_rep_t = undefined;

    // If @sizeOf(src_rep_t) < @sizeOf(int), the subtraction result is promoted
    // to (signed) int.  To avoid that, explicitly cast to src_rep_t.
    if ((src_rep_t)(aAbs -% srcMinNormal) < srcInfinity -% srcMinNormal) {
        // a is a normal number.
        // Extend to the destination type by shifting the significand and
        // exponent into the proper position and rebiasing the exponent.
        absResult = dst_rep_t(aAbs) << (dstSigBits -% srcSigBits);
        absResult += dst_rep_t(@bitCast(u32, dstExpBias -% srcExpBias)) << dstSigBits;
    } else if (aAbs >= srcInfinity) {
        // a is NaN or infinity.
        // Conjure the result by beginning with infinity, then setting the qNaN
        // bit (if needed) and right-aligning the rest of the trailing NaN
        // payload field.
        absResult = dst_rep_t(@bitCast(u32, dstInfExp)) << dstSigBits;
        absResult |= (dst_rep_t)(aAbs & srcQNaN) << (dstSigBits - srcSigBits);
        absResult |= (dst_rep_t)(aAbs & srcNaNCode) << (dstSigBits - srcSigBits);
    } else if (aAbs != 0) {
        // a is denormal.
        // renormalize the significand and clear the leading bit, then insert
        // the correct adjusted exponent in the destination type.
        const scale: i32 = @clz(aAbs) - @clz(srcMinNormal);
        absResult = dst_rep_t(aAbs) << @intCast(DstShift, dstSigBits - srcSigBits + scale);
        absResult ^= dstMinNormal;
        const resultExponent: i32 = dstExpBias - srcExpBias - scale + 1;
        absResult |= dst_rep_t(@bitCast(u32, resultExponent)) << @intCast(DstShift, dstSigBits);
    } else {
        // a is zero.
        absResult = 0;
    }

    // Apply the signbit to (dst_t)abs(a).
    const result: dst_rep_t align(@alignOf(dst_t)) = absResult | dst_rep_t(sign) << @intCast(DstShift, dstBits - srcBits);
    return @bitCast(dst_t, result);
}

test "import extendXfYf2" {
    _ = @import("extendXfYf2_test.zig");
}

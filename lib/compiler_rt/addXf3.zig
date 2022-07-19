// Ported from:
//
// https://github.com/llvm/llvm-project/blob/02d85149a05cb1f6dc49f0ba7a2ceca53718ae17/compiler-rt/lib/builtins/fp_add_impl.inc

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const arch = builtin.cpu.arch;
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;

const common = @import("common.zig");
const normalize = common.normalize;
pub const panic = common.panic;

comptime {
    @export(__addsf3, .{ .name = "__addsf3", .linkage = linkage });
    @export(__adddf3, .{ .name = "__adddf3", .linkage = linkage });
    @export(__addxf3, .{ .name = "__addxf3", .linkage = linkage });
    @export(__addtf3, .{ .name = "__addtf3", .linkage = linkage });

    @export(__subsf3, .{ .name = "__subsf3", .linkage = linkage });
    @export(__subdf3, .{ .name = "__subdf3", .linkage = linkage });
    @export(__subxf3, .{ .name = "__subxf3", .linkage = linkage });
    @export(__subtf3, .{ .name = "__subtf3", .linkage = linkage });

    if (!is_test) {
        if (arch.isARM() or arch.isThumb()) {
            @export(__aeabi_fadd, .{ .name = "__aeabi_fadd", .linkage = linkage });
            @export(__aeabi_dadd, .{ .name = "__aeabi_dadd", .linkage = linkage });
            @export(__aeabi_fsub, .{ .name = "__aeabi_fsub", .linkage = linkage });
            @export(__aeabi_dsub, .{ .name = "__aeabi_dsub", .linkage = linkage });
        }

        if (arch.isPPC() or arch.isPPC64()) {
            @export(__addkf3, .{ .name = "__addkf3", .linkage = linkage });
            @export(__subkf3, .{ .name = "__subkf3", .linkage = linkage });
        }
    }
}

pub fn __addsf3(a: f32, b: f32) callconv(.C) f32 {
    return addXf3(f32, a, b);
}

pub fn __adddf3(a: f64, b: f64) callconv(.C) f64 {
    return addXf3(f64, a, b);
}

pub fn __addxf3(a: f80, b: f80) callconv(.C) f80 {
    return addXf3(f80, a, b);
}

pub fn __subxf3(a: f80, b: f80) callconv(.C) f80 {
    var b_rep = std.math.break_f80(b);
    b_rep.exp ^= 0x8000;
    return __addxf3(a, std.math.make_f80(b_rep));
}

pub fn __addtf3(a: f128, b: f128) callconv(.C) f128 {
    return addXf3(f128, a, b);
}

pub fn __addkf3(a: f128, b: f128) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, __addtf3, .{ a, b });
}

pub fn __subsf3(a: f32, b: f32) callconv(.C) f32 {
    const neg_b = @bitCast(f32, @bitCast(u32, b) ^ (@as(u32, 1) << 31));
    return addXf3(f32, a, neg_b);
}

pub fn __subdf3(a: f64, b: f64) callconv(.C) f64 {
    const neg_b = @bitCast(f64, @bitCast(u64, b) ^ (@as(u64, 1) << 63));
    return addXf3(f64, a, neg_b);
}

pub fn __subtf3(a: f128, b: f128) callconv(.C) f128 {
    const neg_b = @bitCast(f128, @bitCast(u128, b) ^ (@as(u128, 1) << 127));
    return addXf3(f128, a, neg_b);
}

pub fn __subkf3(a: f128, b: f128) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, __subtf3, .{ a, b });
}

pub fn __aeabi_fadd(a: f32, b: f32) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __addsf3, .{ a, b });
}

pub fn __aeabi_dadd(a: f64, b: f64) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __adddf3, .{ a, b });
}

pub fn __aeabi_fsub(a: f32, b: f32) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __subsf3, .{ a, b });
}

pub fn __aeabi_dsub(a: f64, b: f64) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __subdf3, .{ a, b });
}

// TODO: restore inline keyword, see: https://github.com/ziglang/zig/issues/2154
pub fn addXf3(comptime T: type, a: T, b: T) T {
    const bits = @typeInfo(T).Float.bits;
    const Z = std.meta.Int(.unsigned, bits);
    const S = std.meta.Int(.unsigned, bits - @clz(Z, @as(Z, bits) - 1));

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
    const qnanRep = @bitCast(Z, math.nan(T)) | quietBit;

    var aRep = @bitCast(Z, a);
    var bRep = @bitCast(Z, b);
    const aAbs = aRep & absMask;
    const bAbs = bRep & absMask;

    const infRep = @bitCast(Z, math.inf(T));

    // Detect if a or b is zero, infinity, or NaN.
    if (aAbs -% @as(Z, 1) >= infRep - @as(Z, 1) or
        bAbs -% @as(Z, 1) >= infRep - @as(Z, 1))
    {
        // NaN + anything = qNaN
        if (aAbs > infRep) return @bitCast(T, @bitCast(Z, a) | quietBit);
        // anything + NaN = qNaN
        if (bAbs > infRep) return @bitCast(T, @bitCast(Z, b) | quietBit);

        if (aAbs == infRep) {
            // +/-infinity + -/+infinity = qNaN
            if ((@bitCast(Z, a) ^ @bitCast(Z, b)) == signBit) {
                return @bitCast(T, qnanRep);
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
                return @bitCast(T, @bitCast(Z, a) & @bitCast(Z, b));
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
    var aExponent = @intCast(i32, (aRep >> significandBits) & maxExponent);
    var bExponent = @intCast(i32, (bRep >> significandBits) & maxExponent);
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
    const @"align" = @intCast(u32, aExponent - bExponent);
    if (@"align" != 0) {
        if (@"align" < typeWidth) {
            const sticky = if (bSignificand << @intCast(S, typeWidth - @"align") != 0) @as(Z, 1) else 0;
            bSignificand = (bSignificand >> @truncate(S, @"align")) | sticky;
        } else {
            bSignificand = 1; // sticky; b is known to be non-zero.
        }
    }
    if (subtraction) {
        aSignificand -= bSignificand;
        // If a == -b, return +zero.
        if (aSignificand == 0) return @bitCast(T, @as(Z, 0));

        // If partial cancellation occured, we need to left-shift the result
        // and adjust the exponent:
        if (aSignificand < integerBit << 3) {
            const shift = @intCast(i32, @clz(Z, aSignificand)) - @intCast(i32, @clz(std.meta.Int(.unsigned, bits), integerBit << 3));
            aSignificand <<= @intCast(S, shift);
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
    if (aExponent >= maxExponent) return @bitCast(T, infRep | resultSign);

    if (aExponent <= 0) {
        // Result is denormal; the exponent and round/sticky bits are zero.
        // All we need to do is shift the significand and apply the correct sign.
        aSignificand >>= @intCast(S, 4 - aExponent);
        return @bitCast(T, resultSign | aSignificand);
    }

    // Low three bits are round, guard, and sticky.
    const roundGuardSticky = aSignificand & 0x7;

    // Shift the significand into place, and mask off the integer bit, if it's implicit.
    var result = (aSignificand >> 3) & significandMask;

    // Insert the exponent and sign.
    result |= @intCast(Z, aExponent) << significandBits;
    result |= resultSign;

    // Final rounding.  The result may overflow to infinity, but that is the
    // correct result in that case.
    if (roundGuardSticky > 0x4) result += 1;
    if (roundGuardSticky == 0x4) result += result & 1;

    // Restore any explicit integer bit, if it was rounded off
    if (significandBits != fractionalBits) {
        if ((result >> significandBits) != 0) result |= integerBit;
    }

    return @bitCast(T, result);
}

test {
    _ = @import("addXf3_test.zig");
}

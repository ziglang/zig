// Ported from:
//
// https://github.com/llvm/llvm-project/blob/02d85149a05cb1f6dc49f0ba7a2ceca53718ae17/compiler-rt/lib/builtins/fp_add_impl.inc

const std = @import("std");
const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

pub fn __addsf3(a: f32, b: f32) callconv(.C) f32 {
    return addXf3(f32, a, b);
}

pub fn __adddf3(a: f64, b: f64) callconv(.C) f64 {
    return addXf3(f64, a, b);
}

pub fn __addtf3(a: f128, b: f128) callconv(.C) f128 {
    return addXf3(f128, a, b);
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
fn normalize(comptime T: type, significand: *std.meta.Int(.unsigned, @typeInfo(T).Float.bits)) i32 {
    const bits = @typeInfo(T).Float.bits;
    const Z = std.meta.Int(.unsigned, bits);
    const S = std.meta.Int(.unsigned, bits - @clz(Z, @as(Z, bits) - 1));
    const significandBits = std.math.floatMantissaBits(T);
    const implicitBit = @as(Z, 1) << significandBits;

    const shift = @clz(std.meta.Int(.unsigned, bits), significand.*) - @clz(Z, implicitBit);
    significand.* <<= @intCast(S, shift);
    return 1 - shift;
}

// TODO: restore inline keyword, see: https://github.com/ziglang/zig/issues/2154
fn addXf3(comptime T: type, a: T, b: T) T {
    const bits = @typeInfo(T).Float.bits;
    const Z = std.meta.Int(.unsigned, bits);
    const S = std.meta.Int(.unsigned, bits - @clz(Z, @as(Z, bits) - 1));

    const typeWidth = bits;
    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);

    const implicitBit = (@as(Z, 1) << significandBits);
    const quietBit = implicitBit >> 1;
    const significandMask = implicitBit - 1;

    const absMask = signBit - 1;
    const exponentMask = absMask ^ significandMask;
    const qnanRep = exponentMask | quietBit;

    var aRep = @bitCast(Z, a);
    var bRep = @bitCast(Z, b);
    const aAbs = aRep & absMask;
    const bAbs = bRep & absMask;

    const infRep = @bitCast(Z, std.math.inf(T));

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
    aSignificand = (aSignificand | implicitBit) << 3;
    bSignificand = (bSignificand | implicitBit) << 3;

    // Shift the significand of b by the difference in exponents, with a sticky
    // bottom bit to get rounding correct.
    const @"align" = @intCast(Z, aExponent - bExponent);
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
        if (aSignificand < implicitBit << 3) {
            const shift = @intCast(i32, @clz(Z, aSignificand)) - @intCast(i32, @clz(std.meta.Int(.unsigned, bits), implicitBit << 3));
            aSignificand <<= @intCast(S, shift);
            aExponent -= shift;
        }
    } else { // addition
        aSignificand += bSignificand;

        // If the addition carried up, we need to right-shift the result and
        // adjust the exponent:
        if (aSignificand & (implicitBit << 4) != 0) {
            const sticky = aSignificand & 1;
            aSignificand = aSignificand >> 1 | sticky;
            aExponent += 1;
        }
    }

    // If we have overflowed the type, return +/- infinity:
    if (aExponent >= maxExponent) return @bitCast(T, infRep | resultSign);

    if (aExponent <= 0) {
        // Result is denormal before rounding; the exponent is zero and we
        // need to shift the significand.
        const shift = @intCast(Z, 1 - aExponent);
        const sticky = if (aSignificand << @intCast(S, typeWidth - shift) != 0) @as(Z, 1) else 0;
        aSignificand = aSignificand >> @intCast(S, shift | sticky);
        aExponent = 0;
    }

    // Low three bits are round, guard, and sticky.
    const roundGuardSticky = aSignificand & 0x7;

    // Shift the significand into place, and mask off the implicit bit.
    var result = (aSignificand >> 3) & significandMask;

    // Insert the exponent and sign.
    result |= @intCast(Z, aExponent) << significandBits;
    result |= resultSign;

    // Final rounding.  The result may overflow to infinity, but that is the
    // correct result in that case.
    if (roundGuardSticky > 0x4) result += 1;
    if (roundGuardSticky == 0x4) result += result & 1;

    return @bitCast(T, result);
}

fn normalize_f80(exp: *i32, significand: *u80) void {
    const shift = @clz(u64, @truncate(u64, significand.*));
    significand.* = (significand.* << shift);
    exp.* += -@as(i8, shift);
}

pub fn __addxf3(a: f80, b: f80) callconv(.C) f80 {
    var a_rep = std.math.break_f80(a);
    var b_rep = std.math.break_f80(b);
    var a_exp: i32 = a_rep.exp & 0x7FFF;
    var b_exp: i32 = b_rep.exp & 0x7FFF;

    const significand_bits = std.math.floatMantissaBits(f80);
    const int_bit = 0x8000000000000000;
    const significand_mask = 0x7FFFFFFFFFFFFFFF;
    const qnan_bit = 0xC000000000000000;
    const max_exp = 0x7FFF;
    const sign_bit = 0x8000;

    // Detect if a or b is infinity, or NaN.
    if (a_exp == max_exp) {
        if (a_rep.fraction ^ int_bit == 0) {
            if (b_exp == max_exp and (b_rep.fraction ^ int_bit == 0)) {
                // +/-infinity + -/+infinity = qNaN
                return std.math.qnan_f80;
            }
            // +/-infinity + anything = +/- infinity
            return a;
        } else {
            std.debug.assert(a_rep.fraction & significand_mask != 0);
            // NaN + anything = qNaN
            a_rep.fraction |= qnan_bit;
            return std.math.make_f80(a_rep);
        }
    }
    if (b_exp == max_exp) {
        if (b_rep.fraction ^ int_bit == 0) {
            // anything + +/-infinity = +/-infinity
            return b;
        } else {
            std.debug.assert(b_rep.fraction & significand_mask != 0);
            // anything + NaN = qNaN
            b_rep.fraction |= qnan_bit;
            return std.math.make_f80(b_rep);
        }
    }

    const a_zero = (a_rep.fraction | @bitCast(u32, a_exp)) == 0;
    const b_zero = (b_rep.fraction | @bitCast(u32, b_exp)) == 0;
    if (a_zero) {
        // zero + anything = anything
        if (b_zero) {
            // but we need to get the sign right for zero + zero
            a_rep.exp &= b_rep.exp;
            return std.math.make_f80(a_rep);
        } else {
            return b;
        }
    } else if (b_zero) {
        // anything + zero = anything
        return a;
    }

    var a_int: u80 = a_rep.fraction | (@as(u80, a_rep.exp & max_exp) << significand_bits);
    var b_int: u80 = b_rep.fraction | (@as(u80, b_rep.exp & max_exp) << significand_bits);

    // Swap a and b if necessary so that a has the larger absolute value.
    if (b_int > a_int) {
        const temp = a_rep;
        a_rep = b_rep;
        b_rep = temp;
    }

    // Extract the exponent and significand from the (possibly swapped) a and b.
    a_exp = a_rep.exp & max_exp;
    b_exp = b_rep.exp & max_exp;
    a_int = a_rep.fraction;
    b_int = b_rep.fraction;

    // Normalize any denormals, and adjust the exponent accordingly.
    normalize_f80(&a_exp, &a_int);
    normalize_f80(&b_exp, &b_int);

    // The sign of the result is the sign of the larger operand, a.  If they
    // have opposite signs, we are performing a subtraction; otherwise addition.
    const result_sign = a_rep.exp & sign_bit;
    const subtraction = (a_rep.exp ^ b_rep.exp) & sign_bit != 0;

    // Shift the significands to give us round, guard and sticky, and or in the
    // implicit significand bit.  (If we fell through from the denormal path it
    // was already set by normalize( ), but setting it twice won't hurt
    // anything.)
    a_int = a_int << 3;
    b_int = b_int << 3;

    // Shift the significand of b by the difference in exponents, with a sticky
    // bottom bit to get rounding correct.
    const @"align" = @intCast(u80, a_exp - b_exp);
    if (@"align" != 0) {
        if (@"align" < 80) {
            const sticky = if (b_int << @intCast(u7, 80 - @"align") != 0) @as(u80, 1) else 0;
            b_int = (b_int >> @truncate(u7, @"align")) | sticky;
        } else {
            b_int = 1; // sticky; b is known to be non-zero.
        }
    }
    if (subtraction) {
        a_int -= b_int;
        // If a == -b, return +zero.
        if (a_int == 0) return 0.0;

        // If partial cancellation occurred, we need to left-shift the result
        // and adjust the exponent:
        if (a_int < int_bit << 3) {
            const shift = @intCast(i32, @clz(u80, a_int)) - @intCast(i32, @clz(u80, @as(u80, int_bit) << 3));
            a_int <<= @intCast(u7, shift);
            a_exp -= shift;
        }
    } else { // addition
        a_int += b_int;

        // If the addition carried up, we need to right-shift the result and
        // adjust the exponent:
        if (a_int & (int_bit << 4) != 0) {
            const sticky = a_int & 1;
            a_int = a_int >> 1 | sticky;
            a_exp += 1;
        }
    }

    // If we have overflowed the type, return +/- infinity:
    if (a_exp >= max_exp) {
        a_rep.exp = max_exp | result_sign;
        a_rep.fraction = int_bit; // integer bit is set for +/-inf
        return std.math.make_f80(a_rep);
    }

    if (a_exp <= 0) {
        // Result is denormal before rounding; the exponent is zero and we
        // need to shift the significand.
        const shift = @intCast(u80, 1 - a_exp);
        const sticky = if (a_int << @intCast(u7, 80 - shift) != 0) @as(u1, 1) else 0;
        a_int = a_int >> @intCast(u7, shift | sticky);
        a_exp = 0;
    }

    // Low three bits are round, guard, and sticky.
    const round_guard_sticky = @truncate(u3, a_int);

    // Shift the significand into place.
    a_int = @truncate(u64, a_int >> 3);

    // // Insert the exponent and sign.
    a_int |= (@intCast(u80, a_exp) | result_sign) << significand_bits;

    // Final rounding.  The result may overflow to infinity, but that is the
    // correct result in that case.
    if (round_guard_sticky > 0x4) a_int += 1;
    if (round_guard_sticky == 0x4) a_int += a_int & 1;

    a_rep.fraction = @truncate(u64, a_int);
    a_rep.exp = @truncate(u16, a_int >> significand_bits);
    return std.math.make_f80(a_rep);
}

pub fn __subxf3(a: f80, b: f80) callconv(.C) f80 {
    var b_rep = std.math.break_f80(b);
    b_rep.exp ^= 0x8000;
    return __addxf3(a, std.math.make_f80(b_rep));
}

test {
    _ = @import("addXf3_test.zig");
}

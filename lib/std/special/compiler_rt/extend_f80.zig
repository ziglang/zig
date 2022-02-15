const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;
const native_arch = builtin.cpu.arch;

// AArch64 is the only ABI (at the moment) to support f16 arguments without the
// need for extending them to wider fp types.
pub const F16T = if (native_arch.isAARCH64()) f16 else u16;

pub fn __extendhfxf2(a: F16T) callconv(.C) f80 {
    return extendF80(f16, @bitCast(u16, a));
}

pub fn __extendsfxf2(a: f32) callconv(.C) f80 {
    return extendF80(f32, @bitCast(u32, a));
}

pub fn __extenddfxf2(a: f64) callconv(.C) f80 {
    return extendF80(f64, @bitCast(u64, a));
}

inline fn extendF80(comptime src_t: type, a: std.meta.Int(.unsigned, @typeInfo(src_t).Float.bits)) f80 {
    @setRuntimeSafety(builtin.is_test);

    const src_rep_t = std.meta.Int(.unsigned, @typeInfo(src_t).Float.bits);
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
        dst.exp = @intCast(u16, a_abs >> src_sig_bits);
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
        const scale: u16 = @clz(src_rep_t, a_abs) -
            @clz(src_rep_t, @as(src_rep_t, src_min_normal));

        dst.fraction = @as(u64, a_abs) << @intCast(u6, dst_sig_bits - src_sig_bits + scale);
        dst.fraction |= dst_int_bit; // bit 64 is always set for normal numbers
        dst.exp = @truncate(u16, a_abs >> @intCast(u4, src_sig_bits - scale));
        dst.exp ^= 1;
        dst.exp |= dst_exp_bias - src_exp_bias - scale + 1;
    } else {
        // a is zero.
        dst.exp = 0;
        dst.fraction = 0;
    }

    dst.exp |= sign;
    return std.math.make_f80(dst);
}

pub fn __extendxftf2(a: f80) callconv(.C) f128 {
    @setRuntimeSafety(builtin.is_test);

    const src_int_bit: u64 = 0x8000000000000000;
    const src_sig_mask = ~src_int_bit;
    const src_sig_bits = std.math.floatMantissaBits(f80) - 1; // -1 for the integer bit
    const dst_sig_bits = std.math.floatMantissaBits(f128);

    const dst_bits = @bitSizeOf(f128);

    const dst_min_normal = @as(u128, 1) << dst_sig_bits;

    // Break a into a sign and representation of the absolute value
    var a_rep = std.math.break_f80(a);
    const sign = a_rep.exp & 0x8000;
    a_rep.exp &= 0x7FFF;
    var abs_result: u128 = undefined;

    if (a_rep.exp == 0 and a_rep.fraction == 0) {
        // zero
        abs_result = 0;
    } else if (a_rep.exp == 0x7FFF) {
        // a is nan or infinite
        abs_result = @as(u128, a_rep.fraction) << (dst_sig_bits - src_sig_bits);
        abs_result |= @as(u128, a_rep.exp) << dst_sig_bits;
    } else if (a_rep.fraction & src_int_bit != 0) {
        // a is a normal value
        abs_result = @as(u128, a_rep.fraction & src_sig_mask) << (dst_sig_bits - src_sig_bits);
        abs_result |= @as(u128, a_rep.exp) << dst_sig_bits;
    } else {
        // a is denormal
        // renormalize the significand and clear the leading bit and integer part,
        // then insert the correct adjusted exponent in the destination type.
        const scale: u32 = @clz(u64, a_rep.fraction);
        abs_result = @as(u128, a_rep.fraction) << @intCast(u7, dst_sig_bits - src_sig_bits + scale + 1);
        abs_result ^= dst_min_normal;
        abs_result |= @as(u128, scale + 1) << dst_sig_bits;
    }

    // Apply the signbit to (dst_t)abs(a).
    const result: u128 align(@alignOf(f128)) = abs_result | @as(u128, sign) << (dst_bits - 16);
    return @bitCast(f128, result);
}

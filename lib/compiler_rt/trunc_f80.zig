const std = @import("std");
const builtin = @import("builtin");
const arch = builtin.cpu.arch;
const testing = std.testing;
const is_test = builtin.is_test;
const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
pub const panic = @import("common.zig").panic;

comptime {
    @export(__truncxfhf2, .{ .name = "__truncxfhf2", .linkage = linkage });
    @export(__truncxfsf2, .{ .name = "__truncxfsf2", .linkage = linkage });
    @export(__truncxfdf2, .{ .name = "__truncxfdf2", .linkage = linkage });
    @export(__trunctfxf2, .{ .name = "__trunctfxf2", .linkage = linkage });
}

// AArch64 is the only ABI (at the moment) to support f16 arguments without the
// need for extending them to wider fp types.
const F16T = if (arch.isAARCH64()) f16 else u16;

pub fn __truncxfhf2(a: f80) callconv(.C) F16T {
    return @bitCast(F16T, trunc(f16, a));
}

pub fn __truncxfsf2(a: f80) callconv(.C) f32 {
    return trunc(f32, a);
}

pub fn __truncxfdf2(a: f80) callconv(.C) f64 {
    return trunc(f64, a);
}

inline fn trunc(comptime dst_t: type, a: f80) dst_t {
    @setRuntimeSafety(builtin.is_test);

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
        abs_result |= @truncate(dst_rep_t, a_rep.fraction >> (src_sig_bits - dst_sig_bits));
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
        abs_result = @intCast(dst_rep_t, dst_inf_exp) << dst_sig_bits;
        abs_result |= dst_qnan;
        abs_result |= @intCast(dst_rep_t, (a_rep.fraction >> (src_sig_bits - dst_sig_bits)) & dst_nan_mask);
    } else if (a_rep.exp >= overflow) {
        // a overflows to infinity.
        abs_result = @intCast(dst_rep_t, dst_inf_exp) << dst_sig_bits;
    } else {
        // a underflows on conversion to the destination type or is an exact
        // zero.  The result may be a denormal or zero.  Extract the exponent
        // to get the shift amount for the denormalization.
        const shift = src_exp_bias - dst_exp_bias - a_rep.exp;

        // Right shift by the denormalization amount with sticky.
        if (shift > src_sig_bits) {
            abs_result = 0;
        } else {
            const sticky = @boolToInt(a_rep.fraction << @intCast(u6, shift) != 0);
            const denormalized_significand = a_rep.fraction >> @intCast(u6, shift) | sticky;
            abs_result = @intCast(dst_rep_t, denormalized_significand >> (src_sig_bits - dst_sig_bits));
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
    return @bitCast(dst_t, result);
}

pub fn __trunctfxf2(a: f128) callconv(.C) f80 {
    const src_sig_bits = std.math.floatMantissaBits(f128);
    const dst_sig_bits = std.math.floatMantissaBits(f80) - 1; // -1 for the integer bit

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const src_bits = @typeInfo(f128).Float.bits;
    const src_exp_bits = src_bits - src_sig_bits - 1;
    const src_inf_exp = 0x7FFF;

    const src_inf = src_inf_exp << src_sig_bits;
    const src_sign_mask = 1 << (src_sig_bits + src_exp_bits);
    const src_abs_mask = src_sign_mask - 1;
    const round_mask = (1 << (src_sig_bits - dst_sig_bits)) - 1;
    const halfway = 1 << (src_sig_bits - dst_sig_bits - 1);

    // Break a into a sign and representation of the absolute value
    const a_rep = @bitCast(u128, a);
    const a_abs = a_rep & src_abs_mask;
    const sign: u16 = if (a_rep & src_sign_mask != 0) 0x8000 else 0;
    const integer_bit = 1 << 63;

    var res: std.math.F80 = undefined;

    if (a_abs > src_inf) {
        // a is NaN.
        // Conjure the result by beginning with infinity, setting the qNaN
        // bit and inserting the (truncated) trailing NaN field.
        res.exp = 0x7fff;
        res.fraction = 0x8000000000000000;
        res.fraction |= @truncate(u64, a_abs >> (src_sig_bits - dst_sig_bits));
    } else {
        // The exponent of a is within the range of normal numbers in the
        // destination format.  We can convert by simply right-shifting with
        // rounding, adding the explicit integer bit, and adjusting the exponent
        res.fraction = @truncate(u64, a_abs >> (src_sig_bits - dst_sig_bits)) | integer_bit;
        res.exp = @truncate(u16, a_abs >> src_sig_bits);

        const round_bits = a_abs & round_mask;
        if (round_bits > halfway) {
            // Round to nearest
            const carry = @boolToInt(@addWithOverflow(u64, res.fraction, 1, &res.fraction));
            res.exp += carry;
            res.fraction |= @as(u64, carry) << 63; // Restore integer bit after carry
        } else if (round_bits == halfway) {
            // Ties to even
            const carry = @boolToInt(@addWithOverflow(u64, res.fraction, res.fraction & 1, &res.fraction));
            res.exp += carry;
            res.fraction |= @as(u64, carry) << 63; // Restore integer bit after carry
        }
        if (res.exp == 0) res.fraction &= ~@as(u64, integer_bit); // Remove integer bit for de-normals
    }

    res.exp |= sign;
    return std.math.make_f80(res);
}

fn test__trunctfxf2(a: f128, expected: f80) !void {
    const x = __trunctfxf2(a);
    try testing.expect(x == expected);
}

test {
    try test__trunctfxf2(1.5, 1.5);
    try test__trunctfxf2(2.5, 2.5);
    try test__trunctfxf2(-2.5, -2.5);
    try test__trunctfxf2(0.0, 0.0);
}

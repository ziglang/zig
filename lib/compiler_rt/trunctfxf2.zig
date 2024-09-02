const math = @import("std").math;
const common = @import("./common.zig");
const trunc_f80 = @import("./truncf.zig").trunc_f80;

pub const panic = common.panic;

comptime {
    @export(&__trunctfxf2, .{ .name = "__trunctfxf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __trunctfxf2(a: f128) callconv(.C) f80 {
    const src_sig_bits = math.floatMantissaBits(f128);
    const dst_sig_bits = math.floatMantissaBits(f80) - 1; // -1 for the integer bit

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const src_bits = @typeInfo(f128).float.bits;
    const src_exp_bits = src_bits - src_sig_bits - 1;
    const src_inf_exp = 0x7FFF;

    const src_inf = src_inf_exp << src_sig_bits;
    const src_sign_mask = 1 << (src_sig_bits + src_exp_bits);
    const src_abs_mask = src_sign_mask - 1;
    const round_mask = (1 << (src_sig_bits - dst_sig_bits)) - 1;
    const halfway = 1 << (src_sig_bits - dst_sig_bits - 1);

    // Break a into a sign and representation of the absolute value
    const a_rep = @as(u128, @bitCast(a));
    const a_abs = a_rep & src_abs_mask;
    const sign: u16 = if (a_rep & src_sign_mask != 0) 0x8000 else 0;
    const integer_bit = 1 << 63;

    var res: math.F80 = undefined;

    if (a_abs > src_inf) {
        // a is NaN.
        // Conjure the result by beginning with infinity, setting the qNaN
        // bit and inserting the (truncated) trailing NaN field.
        res.exp = 0x7fff;
        res.fraction = 0x8000000000000000;
        res.fraction |= @as(u64, @truncate(a_abs >> (src_sig_bits - dst_sig_bits)));
    } else {
        // The exponent of a is within the range of normal numbers in the
        // destination format.  We can convert by simply right-shifting with
        // rounding, adding the explicit integer bit, and adjusting the exponent
        res.fraction = @as(u64, @truncate(a_abs >> (src_sig_bits - dst_sig_bits))) | integer_bit;
        res.exp = @truncate(a_abs >> src_sig_bits);

        const round_bits = a_abs & round_mask;
        if (round_bits > halfway) {
            // Round to nearest
            const ov = @addWithOverflow(res.fraction, 1);
            res.fraction = ov[0];
            res.exp += ov[1];
            res.fraction |= @as(u64, ov[1]) << 63; // Restore integer bit after carry
        } else if (round_bits == halfway) {
            // Ties to even
            const ov = @addWithOverflow(res.fraction, res.fraction & 1);
            res.fraction = ov[0];
            res.exp += ov[1];
            res.fraction |= @as(u64, ov[1]) << 63; // Restore integer bit after carry
        }
        if (res.exp == 0) res.fraction &= ~@as(u64, integer_bit); // Remove integer bit for de-normals
    }

    res.exp |= sign;
    return res.toFloat();
}

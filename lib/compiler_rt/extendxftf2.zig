const std = @import("std");
const common = @import("./common.zig");

pub const panic = common.panic;

comptime {
    @export(&__extendxftf2, .{ .name = "__extendxftf2", .linkage = common.linkage, .visibility = common.visibility });
}

fn __extendxftf2(a: f80) callconv(.C) f128 {
    const src_int_bit: u64 = 0x8000000000000000;
    const src_sig_mask = ~src_int_bit;
    const src_sig_bits = std.math.floatMantissaBits(f80) - 1; // -1 for the integer bit
    const dst_sig_bits = std.math.floatMantissaBits(f128);

    const dst_bits = @bitSizeOf(f128);

    const dst_min_normal = @as(u128, 1) << dst_sig_bits;

    // Break a into a sign and representation of the absolute value
    var a_rep = std.math.F80.fromFloat(a);
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
        const scale: u32 = @clz(a_rep.fraction);
        abs_result = @as(u128, a_rep.fraction) << @intCast(dst_sig_bits - src_sig_bits + scale + 1);
        abs_result ^= dst_min_normal;
        abs_result |= @as(u128, scale + 1) << dst_sig_bits;
    }

    // Apply the signbit to (dst_t)abs(a).
    const result: u128 align(@alignOf(f128)) = abs_result | @as(u128, sign) << (dst_bits - 16);
    return @bitCast(result);
}

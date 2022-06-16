const Int = @import("std").meta.Int;
const math = @import("std").math;
const Log2Int = math.Log2Int;

pub inline fn floatToInt(comptime I: type, a: anytype) I {
    const F = @TypeOf(a);
    const float_bits = @typeInfo(F).Float.bits;
    const int_bits = @typeInfo(I).Int.bits;
    const rep_t = Int(.unsigned, float_bits);
    const sig_bits = math.floatMantissaBits(F);
    const exp_bits = math.floatExponentBits(F);
    const fractional_bits = math.floatFractionalBits(F);

    const implicit_bit = if (F != f80) (@as(rep_t, 1) << sig_bits) else 0;
    const max_exp = (1 << (exp_bits - 1));
    const exp_bias = max_exp - 1;
    const sig_mask = (@as(rep_t, 1) << sig_bits) - 1;

    // Break a into sign, exponent, significand
    const a_rep: rep_t = @bitCast(rep_t, a);
    const negative = (a_rep >> (float_bits - 1)) != 0;
    const exponent = @intCast(i32, (a_rep << 1) >> (sig_bits + 1)) - exp_bias;
    const significand: rep_t = (a_rep & sig_mask) | implicit_bit;

    // If the exponent is negative, the result rounds to zero.
    if (exponent < 0) return 0;

    // If the value is too large for the integer type, saturate.
    switch (@typeInfo(I).Int.signedness) {
        .unsigned => {
            if (negative) return 0;
            if (@intCast(c_uint, exponent) >= @minimum(int_bits, max_exp)) return math.maxInt(I);
        },
        .signed => if (@intCast(c_uint, exponent) >= @minimum(int_bits - 1, max_exp)) {
            return if (negative) math.minInt(I) else math.maxInt(I);
        },
    }

    // If 0 <= exponent < sig_bits, right shift to get the result.
    // Otherwise, shift left.
    var result: I = undefined;
    if (exponent < fractional_bits) {
        result = @intCast(I, significand >> @intCast(Log2Int(rep_t), fractional_bits - exponent));
    } else {
        result = @intCast(I, significand) << @intCast(Log2Int(I), exponent - fractional_bits);
    }

    if ((@typeInfo(I).Int.signedness == .signed) and negative)
        return ~result +% 1;
    return result;
}

test {
    _ = @import("float_to_int_test.zig");
}

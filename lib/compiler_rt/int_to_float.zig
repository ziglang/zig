const Int = @import("std").meta.Int;
const math = @import("std").math;

pub fn intToFloat(comptime T: type, x: anytype) T {
    if (x == 0) return 0;

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const Z = Int(.unsigned, @bitSizeOf(@TypeOf(x)));
    const uT = Int(.unsigned, @bitSizeOf(T));
    const inf = math.inf(T);
    const float_bits = @bitSizeOf(T);
    const int_bits = @bitSizeOf(@TypeOf(x));
    const exp_bits = math.floatExponentBits(T);
    const fractional_bits = math.floatFractionalBits(T);
    const exp_bias = math.maxInt(Int(.unsigned, exp_bits - 1));
    const implicit_bit = if (T != f80) @as(uT, 1) << fractional_bits else 0;
    const max_exp = exp_bias;

    // Sign
    var abs_val = math.absCast(x);
    const sign_bit = if (x < 0) @as(uT, 1) << (float_bits - 1) else 0;
    var result: uT = sign_bit;

    // Compute significand
    var exp = int_bits - @clz(Z, abs_val) - 1;
    if (int_bits <= fractional_bits or exp <= fractional_bits) {
        const shift_amt = fractional_bits - @intCast(math.Log2Int(uT), exp);

        // Shift up result to line up with the significand - no rounding required
        result = (@intCast(uT, abs_val) << shift_amt);
        result ^= implicit_bit; // Remove implicit integer bit
    } else {
        var shift_amt = @intCast(math.Log2Int(Z), exp - fractional_bits);
        const exact_tie: bool = @ctz(Z, abs_val) == shift_amt - 1;

        // Shift down result and remove implicit integer bit
        result = @intCast(uT, (abs_val >> (shift_amt - 1))) ^ (implicit_bit << 1);

        // Round result, including round-to-even for exact ties
        result = ((result + 1) >> 1) & ~@as(uT, @boolToInt(exact_tie));
    }

    // Compute exponent
    if ((int_bits > max_exp) and (exp > max_exp)) // If exponent too large, overflow to infinity
        return @bitCast(T, sign_bit | @bitCast(uT, inf));

    result += (@as(uT, exp) + exp_bias) << math.floatMantissaBits(T);

    // If the result included a carry, we need to restore the explicit integer bit
    if (T == f80) result |= 1 << fractional_bits;

    return @bitCast(T, sign_bit | result);
}

test {
    _ = @import("int_to_float_test.zig");
}

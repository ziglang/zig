//! Conversion of hex-float representation into an accurate value.
//
// Derived from golang strconv/atof.go.

const std = @import("std");
const math = std.math;
const common = @import("common.zig");
const Number = common.Number;
const floatFromUnsigned = common.floatFromUnsigned;

// converts the form 0xMMM.NNNpEEE.
//
// MMM.NNN = mantissa
// EEE = exponent
//
// MMM.NNN is stored as an integer, the exponent is offset.
pub fn convertHex(comptime T: type, n_: Number(T)) T {
    const MantissaT = common.mantissaType(T);
    var n = n_;

    if (n.mantissa == 0) {
        return if (n.negative) -0.0 else 0.0;
    }

    const max_exp = math.floatExponentMax(T);
    const min_exp = math.floatExponentMin(T);
    const mantissa_bits = math.floatMantissaBits(T);
    const exp_bits = math.floatExponentBits(T);
    const exp_bias = min_exp - 1;

    // mantissa now implicitly divided by 2^mantissa_bits
    n.exponent += mantissa_bits;

    // Shift mantissa and exponent to bring representation into float range.
    // Eventually we want a mantissa with a leading 1-bit followed by mantbits other bits.
    // For rounding, we need two more, where the bottom bit represents
    // whether that bit or any later bit was non-zero.
    // (If the mantissa has already lost non-zero bits, trunc is true,
    // and we OR in a 1 below after shifting left appropriately.)
    while (n.mantissa != 0 and n.mantissa >> (mantissa_bits + 2) == 0) {
        n.mantissa <<= 1;
        n.exponent -= 1;
    }
    if (n.many_digits) {
        n.mantissa |= 1;
    }
    while (n.mantissa >> (1 + mantissa_bits + 2) != 0) {
        n.mantissa = (n.mantissa >> 1) | (n.mantissa & 1);
        n.exponent += 1;
    }

    // If exponent is too negative,
    // denormalize in hopes of making it representable.
    // (The -2 is for the rounding bits.)
    while (n.mantissa > 1 and n.exponent < min_exp - 2) {
        n.mantissa = (n.mantissa >> 1) | (n.mantissa & 1);
        n.exponent += 1;
    }

    // Round using two bottom bits.
    var round = n.mantissa & 3;
    n.mantissa >>= 2;
    round |= n.mantissa & 1; // round to even (round up if mantissa is odd)
    n.exponent += 2;
    if (round == 3) {
        n.mantissa += 1;
        if (n.mantissa == 1 << (1 + mantissa_bits)) {
            n.mantissa >>= 1;
            n.exponent += 1;
        }
    }

    // Denormal or zero
    if (n.mantissa >> mantissa_bits == 0) {
        n.exponent = exp_bias;
    }

    // Infinity and range error
    if (n.exponent > max_exp) {
        return math.inf(T);
    }

    var bits = n.mantissa & ((1 << mantissa_bits) - 1);
    bits |= @as(MantissaT, @intCast((n.exponent - exp_bias) & ((1 << exp_bits) - 1))) << mantissa_bits;
    if (n.negative) {
        bits |= 1 << (mantissa_bits + exp_bits);
    }
    return floatFromUnsigned(T, MantissaT, bits);
}

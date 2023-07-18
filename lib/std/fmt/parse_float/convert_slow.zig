const std = @import("std");
const math = std.math;
const common = @import("common.zig");
const BiasedFp = common.BiasedFp;
const Decimal = @import("decimal.zig").Decimal;
const mantissaType = common.mantissaType;

const max_shift = 60;
const num_powers = 19;
const powers = [_]u8{ 0, 3, 6, 9, 13, 16, 19, 23, 26, 29, 33, 36, 39, 43, 46, 49, 53, 56, 59 };

pub fn getShift(n: usize) usize {
    return if (n < num_powers) powers[n] else max_shift;
}

/// Parse the significant digits and biased, binary exponent of a float.
///
/// This is a fallback algorithm that uses a big-integer representation
/// of the float, and therefore is considerably slower than faster
/// approximations. However, it will always determine how to round
/// the significant digits to the nearest machine float, allowing
/// use to handle near half-way cases.
///
/// Near half-way cases are halfway between two consecutive machine floats.
/// For example, the float `16777217.0` has a bitwise representation of
/// `100000000000000000000000 1`. Rounding to a single-precision float,
/// the trailing `1` is truncated. Using round-nearest, tie-even, any
/// value above `16777217.0` must be rounded up to `16777218.0`, while
/// any value before or equal to `16777217.0` must be rounded down
/// to `16777216.0`. These near-halfway conversions therefore may require
/// a large number of digits to unambiguously determine how to round.
///
/// The algorithms described here are based on "Processing Long Numbers Quickly",
/// available here: <https://arxiv.org/pdf/2101.11408.pdf#section.11>.
///
/// Note that this function needs a lot of stack space and is marked
/// cold to hint against inlining into the caller.
pub fn convertSlow(comptime T: type, s: []const u8) BiasedFp(T) {
    @setCold(true);

    const MantissaT = mantissaType(T);
    const min_exponent = -(1 << (math.floatExponentBits(T) - 1)) + 1;
    const infinite_power = (1 << math.floatExponentBits(T)) - 1;
    const mantissa_explicit_bits = math.floatMantissaBits(T);

    var d = Decimal(T).parse(s); // no need to recheck underscores
    if (d.num_digits == 0 or d.decimal_point < Decimal(T).min_exponent) {
        return BiasedFp(T).zero();
    } else if (d.decimal_point >= Decimal(T).max_exponent) {
        return BiasedFp(T).inf(T);
    }

    var exp2: i32 = 0;
    // Shift right toward (1/2 .. 1]
    while (d.decimal_point > 0) {
        const n = @as(usize, @intCast(d.decimal_point));
        const shift = getShift(n);
        d.rightShift(shift);
        if (d.decimal_point < -Decimal(T).decimal_point_range) {
            return BiasedFp(T).zero();
        }
        exp2 += @as(i32, @intCast(shift));
    }
    //  Shift left toward (1/2 .. 1]
    while (d.decimal_point <= 0) {
        const shift = blk: {
            if (d.decimal_point == 0) {
                break :blk switch (d.digits[0]) {
                    5...9 => break,
                    0, 1 => @as(usize, 2),
                    else => 1,
                };
            } else {
                const n = @as(usize, @intCast(-d.decimal_point));
                break :blk getShift(n);
            }
        };
        d.leftShift(shift);
        if (d.decimal_point > Decimal(T).decimal_point_range) {
            return BiasedFp(T).inf(T);
        }
        exp2 -= @as(i32, @intCast(shift));
    }
    // We are now in the range [1/2 .. 1] but the binary format uses [1 .. 2]
    exp2 -= 1;
    while (min_exponent + 1 > exp2) {
        var n = @as(usize, @intCast((min_exponent + 1) - exp2));
        if (n > max_shift) {
            n = max_shift;
        }
        d.rightShift(n);
        exp2 += @as(i32, @intCast(n));
    }
    if (exp2 - min_exponent >= infinite_power) {
        return BiasedFp(T).inf(T);
    }

    // Shift the decimal to the hidden bit, and then round the value
    // to get the high mantissa+1 bits.
    d.leftShift(mantissa_explicit_bits + 1);
    var mantissa = d.round();
    if (mantissa >= (@as(MantissaT, 1) << (mantissa_explicit_bits + 1))) {
        // Rounding up overflowed to the carry bit, need to
        // shift back to the hidden bit.
        d.rightShift(1);
        exp2 += 1;
        mantissa = d.round();
        if ((exp2 - min_exponent) >= infinite_power) {
            return BiasedFp(T).inf(T);
        }
    }
    var power2 = exp2 - min_exponent;
    if (mantissa < (@as(MantissaT, 1) << mantissa_explicit_bits)) {
        power2 -= 1;
    }
    // Zero out all the bits above the explicit mantissa bits.
    mantissa &= (@as(MantissaT, 1) << mantissa_explicit_bits) - 1;
    return .{ .f = mantissa, .e = power2 };
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const enum3 = @import("errol/enum3.zig").enum3;
const enum3_data = @import("errol/enum3.zig").enum3_data;
const lookup_table = @import("errol/lookup.zig").lookup_table;
const HP = @import("errol/lookup.zig").HP;
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;

pub const FloatDecimal = struct {
    digits: []u8,
    exp: i32,
};

pub const RoundMode = enum {
    // Round only the fractional portion (e.g. 1234.23 has precision 2)
    Decimal,
    // Round the entire whole/fractional portion (e.g. 1.23423e3 has precision 5)
    Scientific,
};

/// Round a FloatDecimal as returned by errol3 to the specified fractional precision.
/// All digits after the specified precision should be considered invalid.
pub fn roundToPrecision(float_decimal: *FloatDecimal, precision: usize, mode: RoundMode) void {
    // The round digit refers to the index which we should look at to determine
    // whether we need to round to match the specified precision.
    var round_digit: usize = 0;

    switch (mode) {
        RoundMode.Decimal => {
            if (float_decimal.exp >= 0) {
                round_digit = precision + @intCast(usize, float_decimal.exp);
            } else {
                // if a small negative exp, then adjust we need to offset by the number
                // of leading zeros that will occur.
                const min_exp_required = @intCast(usize, -float_decimal.exp);
                if (precision > min_exp_required) {
                    round_digit = precision - min_exp_required;
                }
            }
        },
        RoundMode.Scientific => {
            round_digit = 1 + precision;
        },
    }

    // It suffices to look at just this digit. We don't round and propagate say 0.04999 to 0.05
    // first, and then to 0.1 in the case of a {.1} single precision.

    // Find the digit which will signify the round point and start rounding backwards.
    if (round_digit < float_decimal.digits.len and float_decimal.digits[round_digit] - '0' >= 5) {
        assert(round_digit >= 0);

        var i = round_digit;
        while (true) {
            if (i == 0) {
                // Rounded all the way past the start. This was of the form 9.999...
                // Slot the new digit in place and increase the exponent.
                float_decimal.exp += 1;

                // Re-size the buffer to use the reserved leading byte.
                const one_before = @intToPtr([*]u8, @ptrToInt(&float_decimal.digits[0]) - 1);
                float_decimal.digits = one_before[0 .. float_decimal.digits.len + 1];
                float_decimal.digits[0] = '1';
                return;
            }

            i -= 1;

            const new_value = (float_decimal.digits[i] - '0' + 1) % 10;
            float_decimal.digits[i] = new_value + '0';

            // must continue rounding until non-9
            if (new_value != 0) {
                return;
            }
        }
    }
}

/// Corrected Errol3 double to ASCII conversion.
pub fn errol3(value: f64, buffer: []u8) FloatDecimal {
    const bits = @bitCast(u64, value);
    const i = tableLowerBound(bits);
    if (i < enum3.len and enum3[i] == bits) {
        const data = enum3_data[i];
        const digits = buffer[1 .. data.str.len + 1];
        mem.copy(u8, digits, data.str);
        return FloatDecimal{
            .digits = digits,
            .exp = data.exp,
        };
    }

    return errol3u(value, buffer);
}

/// Uncorrected Errol3 double to ASCII conversion.
fn errol3u(val: f64, buffer: []u8) FloatDecimal {
    // check if in integer or fixed range
    if (val > 9.007199254740992e15 and val < 3.40282366920938e+38) {
        return errolInt(val, buffer);
    } else if (val >= 16.0 and val < 9.007199254740992e15) {
        return errolFixed(val, buffer);
    }

    // normalize the midpoint

    const e = math.frexp(val).exponent;
    var exp = @floatToInt(i16, math.floor(307 + @intToFloat(f64, e) * 0.30103));
    if (exp < 20) {
        exp = 20;
    } else if (@intCast(usize, exp) >= lookup_table.len) {
        exp = @intCast(i16, lookup_table.len - 1);
    }

    var mid = lookup_table[@intCast(usize, exp)];
    mid = hpProd(mid, val);
    const lten = lookup_table[@intCast(usize, exp)].val;

    exp -= 307;

    var ten: f64 = 1.0;

    while (mid.val > 10.0 or (mid.val == 10.0 and mid.off >= 0.0)) {
        exp += 1;
        hpDiv10(&mid);
        ten /= 10.0;
    }

    while (mid.val < 1.0 or (mid.val == 1.0 and mid.off < 0.0)) {
        exp -= 1;
        hpMul10(&mid);
        ten *= 10.0;
    }

    // compute boundaries
    var high = HP{
        .val = mid.val,
        .off = mid.off + (fpnext(val) - val) * lten * ten / 2.0,
    };
    var low = HP{
        .val = mid.val,
        .off = mid.off + (fpprev(val) - val) * lten * ten / 2.0,
    };

    hpNormalize(&high);
    hpNormalize(&low);

    // normalized boundaries

    while (high.val > 10.0 or (high.val == 10.0 and high.off >= 0.0)) {
        exp += 1;
        hpDiv10(&high);
        hpDiv10(&low);
    }

    while (high.val < 1.0 or (high.val == 1.0 and high.off < 0.0)) {
        exp -= 1;
        hpMul10(&high);
        hpMul10(&low);
    }

    // digit generation

    // We generate digits starting at index 1. If rounding a buffer later then it may be
    // required to generate a preceding digit in some cases (9.999) in which case we use
    // the 0-index for this extra digit.
    var buf_index: usize = 1;
    while (true) {
        var hdig = @floatToInt(u8, math.floor(high.val));
        if ((high.val == @intToFloat(f64, hdig)) and (high.off < 0)) hdig -= 1;

        var ldig = @floatToInt(u8, math.floor(low.val));
        if ((low.val == @intToFloat(f64, ldig)) and (low.off < 0)) ldig -= 1;

        if (ldig != hdig) break;

        buffer[buf_index] = hdig + '0';
        buf_index += 1;
        high.val -= @intToFloat(f64, hdig);
        low.val -= @intToFloat(f64, ldig);
        hpMul10(&high);
        hpMul10(&low);
    }

    const tmp = (high.val + low.val) / 2.0;
    var mdig = @floatToInt(u8, math.floor(tmp + 0.5));
    if ((@intToFloat(f64, mdig) - tmp) == 0.5 and (mdig & 0x1) != 0) mdig -= 1;

    buffer[buf_index] = mdig + '0';
    buf_index += 1;

    return FloatDecimal{
        .digits = buffer[1..buf_index],
        .exp = exp,
    };
}

fn tableLowerBound(k: u64) usize {
    var i = enum3.len;
    var j: usize = 0;

    while (j < enum3.len) {
        if (enum3[j] < k) {
            j = 2 * j + 2;
        } else {
            i = j;
            j = 2 * j + 1;
        }
    }

    return i;
}

/// Compute the product of an HP number and a double.
///   @in: The HP number.
///   @val: The double.
///   &returns: The HP number.
fn hpProd(in: HP, val: f64) HP {
    var hi: f64 = undefined;
    var lo: f64 = undefined;
    split(in.val, &hi, &lo);

    var hi2: f64 = undefined;
    var lo2: f64 = undefined;
    split(val, &hi2, &lo2);

    const p = in.val * val;
    const e = ((hi * hi2 - p) + lo * hi2 + hi * lo2) + lo * lo2;

    return HP{
        .val = p,
        .off = in.off * val + e,
    };
}

/// Split a double into two halves.
///   @val: The double.
///   @hi: The high bits.
///   @lo: The low bits.
fn split(val: f64, hi: *f64, lo: *f64) void {
    hi.* = gethi(val);
    lo.* = val - hi.*;
}

fn gethi(in: f64) f64 {
    const bits = @bitCast(u64, in);
    const new_bits = bits & 0xFFFFFFFFF8000000;
    return @bitCast(f64, new_bits);
}

/// Normalize the number by factoring in the error.
///   @hp: The float pair.
fn hpNormalize(hp: *HP) void {
    const val = hp.val;
    hp.val += hp.off;
    hp.off += val - hp.val;
}

/// Divide the high-precision number by ten.
///   @hp: The high-precision number
fn hpDiv10(hp: *HP) void {
    var val = hp.val;

    hp.val /= 10.0;
    hp.off /= 10.0;

    val -= hp.val * 8.0;
    val -= hp.val * 2.0;

    hp.off += val / 10.0;

    hpNormalize(hp);
}

/// Multiply the high-precision number by ten.
///   @hp: The high-precision number
fn hpMul10(hp: *HP) void {
    const val = hp.val;

    hp.val *= 10.0;
    hp.off *= 10.0;

    var off = hp.val;
    off -= val * 8.0;
    off -= val * 2.0;

    hp.off -= off;

    hpNormalize(hp);
}

/// Integer conversion algorithm, guaranteed correct, optimal, and best.
///  @val: The val.
///  @buf: The output buffer.
///  &return: The exponent.
fn errolInt(val: f64, buffer: []u8) FloatDecimal {
    const pow19 = @as(u128, 1e19);

    assert((val > 9.007199254740992e15) and val < (3.40282366920938e38));

    var mid = @floatToInt(u128, val);
    var low: u128 = mid - fpeint((fpnext(val) - val) / 2.0);
    var high: u128 = mid + fpeint((val - fpprev(val)) / 2.0);

    if (@bitCast(u64, val) & 0x1 != 0) {
        high -= 1;
    } else {
        low -= 1;
    }

    var l64 = @intCast(u64, low % pow19);
    const lf = @intCast(u64, (low / pow19) % pow19);

    var h64 = @intCast(u64, high % pow19);
    const hf = @intCast(u64, (high / pow19) % pow19);

    if (lf != hf) {
        l64 = lf;
        h64 = hf;
        mid = mid / (pow19 / 10);
    }

    var mi: i32 = mismatch10(l64, h64);
    var x: u64 = 1;
    {
        var i: i32 = @boolToInt(lf == hf);
        while (i < mi) : (i += 1) {
            x *= 10;
        }
    }
    const m64 = @truncate(u64, @divTrunc(mid, x));

    if (lf != hf) mi += 19;

    var buf_index = u64toa(m64, buffer) - 1;

    if (mi != 0) {
        buffer[buf_index - 1] += @boolToInt(buffer[buf_index] >= '5');
    } else {
        buf_index += 1;
    }

    return FloatDecimal{
        .digits = buffer[0..buf_index],
        .exp = @intCast(i32, buf_index) + mi,
    };
}

/// Fixed point conversion algorithm, guaranteed correct, optimal, and best.
///  @val: The val.
///  @buf: The output buffer.
///  &return: The exponent.
fn errolFixed(val: f64, buffer: []u8) FloatDecimal {
    assert((val >= 16.0) and (val < 9.007199254740992e15));

    const u = @floatToInt(u64, val);
    const n = @intToFloat(f64, u);

    var mid = val - n;
    var lo = ((fpprev(val) - n) + mid) / 2.0;
    var hi = ((fpnext(val) - n) + mid) / 2.0;

    var buf_index = u64toa(u, buffer);
    var exp = @intCast(i32, buf_index);
    var j = buf_index;
    buffer[j] = 0;

    if (mid != 0.0) {
        while (mid != 0.0) {
            lo *= 10.0;
            const ldig = @floatToInt(i32, lo);
            lo -= @intToFloat(f64, ldig);

            mid *= 10.0;
            const mdig = @floatToInt(i32, mid);
            mid -= @intToFloat(f64, mdig);

            hi *= 10.0;
            const hdig = @floatToInt(i32, hi);
            hi -= @intToFloat(f64, hdig);

            buffer[j] = @intCast(u8, mdig + '0');
            j += 1;

            if (hdig != ldig or j > 50) break;
        }

        if (mid > 0.5) {
            buffer[j - 1] += 1;
        } else if ((mid == 0.5) and (buffer[j - 1] & 0x1) != 0) {
            buffer[j - 1] += 1;
        }
    } else {
        while (buffer[j - 1] == '0') {
            buffer[j - 1] = 0;
            j -= 1;
        }
    }

    buffer[j] = 0;

    return FloatDecimal{
        .digits = buffer[0..j],
        .exp = exp,
    };
}

fn fpnext(val: f64) f64 {
    return @bitCast(f64, @bitCast(u64, val) +% 1);
}

fn fpprev(val: f64) f64 {
    return @bitCast(f64, @bitCast(u64, val) -% 1);
}

pub const c_digits_lut = [_]u8{
    '0', '0', '0', '1', '0', '2', '0', '3', '0', '4', '0', '5', '0', '6',
    '0', '7', '0', '8', '0', '9', '1', '0', '1', '1', '1', '2', '1', '3',
    '1', '4', '1', '5', '1', '6', '1', '7', '1', '8', '1', '9', '2', '0',
    '2', '1', '2', '2', '2', '3', '2', '4', '2', '5', '2', '6', '2', '7',
    '2', '8', '2', '9', '3', '0', '3', '1', '3', '2', '3', '3', '3', '4',
    '3', '5', '3', '6', '3', '7', '3', '8', '3', '9', '4', '0', '4', '1',
    '4', '2', '4', '3', '4', '4', '4', '5', '4', '6', '4', '7', '4', '8',
    '4', '9', '5', '0', '5', '1', '5', '2', '5', '3', '5', '4', '5', '5',
    '5', '6', '5', '7', '5', '8', '5', '9', '6', '0', '6', '1', '6', '2',
    '6', '3', '6', '4', '6', '5', '6', '6', '6', '7', '6', '8', '6', '9',
    '7', '0', '7', '1', '7', '2', '7', '3', '7', '4', '7', '5', '7', '6',
    '7', '7', '7', '8', '7', '9', '8', '0', '8', '1', '8', '2', '8', '3',
    '8', '4', '8', '5', '8', '6', '8', '7', '8', '8', '8', '9', '9', '0',
    '9', '1', '9', '2', '9', '3', '9', '4', '9', '5', '9', '6', '9', '7',
    '9', '8', '9', '9',
};

fn u64toa(value_param: u64, buffer: []u8) usize {
    var value = value_param;
    const kTen8: u64 = 100000000;
    const kTen9: u64 = kTen8 * 10;
    const kTen10: u64 = kTen8 * 100;
    const kTen11: u64 = kTen8 * 1000;
    const kTen12: u64 = kTen8 * 10000;
    const kTen13: u64 = kTen8 * 100000;
    const kTen14: u64 = kTen8 * 1000000;
    const kTen15: u64 = kTen8 * 10000000;
    const kTen16: u64 = kTen8 * kTen8;

    var buf_index: usize = 0;

    if (value < kTen8) {
        const v = @intCast(u32, value);
        if (v < 10000) {
            const d1: u32 = (v / 100) << 1;
            const d2: u32 = (v % 100) << 1;

            if (v >= 1000) {
                buffer[buf_index] = c_digits_lut[d1];
                buf_index += 1;
            }
            if (v >= 100) {
                buffer[buf_index] = c_digits_lut[d1 + 1];
                buf_index += 1;
            }
            if (v >= 10) {
                buffer[buf_index] = c_digits_lut[d2];
                buf_index += 1;
            }
            buffer[buf_index] = c_digits_lut[d2 + 1];
            buf_index += 1;
        } else {
            // value = bbbbcccc
            const b: u32 = v / 10000;
            const c: u32 = v % 10000;

            const d1: u32 = (b / 100) << 1;
            const d2: u32 = (b % 100) << 1;

            const d3: u32 = (c / 100) << 1;
            const d4: u32 = (c % 100) << 1;

            if (value >= 10000000) {
                buffer[buf_index] = c_digits_lut[d1];
                buf_index += 1;
            }
            if (value >= 1000000) {
                buffer[buf_index] = c_digits_lut[d1 + 1];
                buf_index += 1;
            }
            if (value >= 100000) {
                buffer[buf_index] = c_digits_lut[d2];
                buf_index += 1;
            }
            buffer[buf_index] = c_digits_lut[d2 + 1];
            buf_index += 1;

            buffer[buf_index] = c_digits_lut[d3];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[d3 + 1];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[d4];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[d4 + 1];
            buf_index += 1;
        }
    } else if (value < kTen16) {
        const v0: u32 = @intCast(u32, value / kTen8);
        const v1: u32 = @intCast(u32, value % kTen8);

        const b0: u32 = v0 / 10000;
        const c0: u32 = v0 % 10000;

        const d1: u32 = (b0 / 100) << 1;
        const d2: u32 = (b0 % 100) << 1;

        const d3: u32 = (c0 / 100) << 1;
        const d4: u32 = (c0 % 100) << 1;

        const b1: u32 = v1 / 10000;
        const c1: u32 = v1 % 10000;

        const d5: u32 = (b1 / 100) << 1;
        const d6: u32 = (b1 % 100) << 1;

        const d7: u32 = (c1 / 100) << 1;
        const d8: u32 = (c1 % 100) << 1;

        if (value >= kTen15) {
            buffer[buf_index] = c_digits_lut[d1];
            buf_index += 1;
        }
        if (value >= kTen14) {
            buffer[buf_index] = c_digits_lut[d1 + 1];
            buf_index += 1;
        }
        if (value >= kTen13) {
            buffer[buf_index] = c_digits_lut[d2];
            buf_index += 1;
        }
        if (value >= kTen12) {
            buffer[buf_index] = c_digits_lut[d2 + 1];
            buf_index += 1;
        }
        if (value >= kTen11) {
            buffer[buf_index] = c_digits_lut[d3];
            buf_index += 1;
        }
        if (value >= kTen10) {
            buffer[buf_index] = c_digits_lut[d3 + 1];
            buf_index += 1;
        }
        if (value >= kTen9) {
            buffer[buf_index] = c_digits_lut[d4];
            buf_index += 1;
        }
        if (value >= kTen8) {
            buffer[buf_index] = c_digits_lut[d4 + 1];
            buf_index += 1;
        }

        buffer[buf_index] = c_digits_lut[d5];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d5 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d6];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d6 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d7];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d7 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d8];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d8 + 1];
        buf_index += 1;
    } else {
        const a = @intCast(u32, value / kTen16); // 1 to 1844
        value %= kTen16;

        if (a < 10) {
            buffer[buf_index] = '0' + @intCast(u8, a);
            buf_index += 1;
        } else if (a < 100) {
            const i: u32 = a << 1;
            buffer[buf_index] = c_digits_lut[i];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[i + 1];
            buf_index += 1;
        } else if (a < 1000) {
            buffer[buf_index] = '0' + @intCast(u8, a / 100);
            buf_index += 1;

            const i: u32 = (a % 100) << 1;
            buffer[buf_index] = c_digits_lut[i];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[i + 1];
            buf_index += 1;
        } else {
            const i: u32 = (a / 100) << 1;
            const j: u32 = (a % 100) << 1;
            buffer[buf_index] = c_digits_lut[i];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[i + 1];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[j];
            buf_index += 1;
            buffer[buf_index] = c_digits_lut[j + 1];
            buf_index += 1;
        }

        const v0 = @intCast(u32, value / kTen8);
        const v1 = @intCast(u32, value % kTen8);

        const b0: u32 = v0 / 10000;
        const c0: u32 = v0 % 10000;

        const d1: u32 = (b0 / 100) << 1;
        const d2: u32 = (b0 % 100) << 1;

        const d3: u32 = (c0 / 100) << 1;
        const d4: u32 = (c0 % 100) << 1;

        const b1: u32 = v1 / 10000;
        const c1: u32 = v1 % 10000;

        const d5: u32 = (b1 / 100) << 1;
        const d6: u32 = (b1 % 100) << 1;

        const d7: u32 = (c1 / 100) << 1;
        const d8: u32 = (c1 % 100) << 1;

        buffer[buf_index] = c_digits_lut[d1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d1 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d2];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d2 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d3];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d3 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d4];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d4 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d5];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d5 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d6];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d6 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d7];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d7 + 1];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d8];
        buf_index += 1;
        buffer[buf_index] = c_digits_lut[d8 + 1];
        buf_index += 1;
    }

    return buf_index;
}

fn fpeint(from: f64) u128 {
    const bits = @bitCast(u64, from);
    assert((bits & ((1 << 52) - 1)) == 0);

    return @as(u128, 1) << @truncate(u7, (bits >> 52) -% 1023);
}

/// Given two different integers with the same length in terms of the number
/// of decimal digits, index the digits from the right-most position starting
/// from zero, find the first index where the digits in the two integers
/// divergent starting from the highest index.
///   @a: Integer a.
///   @b: Integer b.
///   &returns: An index within [0, 19).
fn mismatch10(a: u64, b: u64) i32 {
    const pow10 = 10000000000;
    const af = a / pow10;
    const bf = b / pow10;

    var i: i32 = 0;
    var a_copy = a;
    var b_copy = b;

    if (af != bf) {
        i = 10;
        a_copy = af;
        b_copy = bf;
    }

    while (true) : (i += 1) {
        a_copy /= 10;
        b_copy /= 10;

        if (a_copy == b_copy) return i;
    }
}

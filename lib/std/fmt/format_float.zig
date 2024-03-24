//! This file implements the ryu floating point conversion algorithm:
//! https://dl.acm.org/doi/pdf/10.1145/3360595

const std = @import("std");
const expectFmt = std.testing.expectFmt;

const special_exponent = 0x7fffffff;

/// Any buffer used for `format` must be at least this large. This is asserted. A runtime check will
/// additionally be performed if more bytes are required.
pub const min_buffer_size = 53;

/// Returns the minimum buffer size needed to print every float of a specific type and format.
pub fn bufferSize(comptime mode: Format, comptime T: type) comptime_int {
    comptime std.debug.assert(@typeInfo(T) == .Float);
    return switch (mode) {
        .scientific => 53,
        // Based on minimum subnormal values.
        .decimal => switch (@bitSizeOf(T)) {
            16 => @max(15, min_buffer_size),
            32 => 55,
            64 => 347,
            80 => 4996,
            128 => 5011,
            else => unreachable,
        },
    };
}

pub const FormatError = error{
    BufferTooSmall,
};

pub const Format = enum {
    scientific,
    decimal,
};

pub const FormatOptions = struct {
    mode: Format = .scientific,
    precision: ?usize = null,
};

/// Format a floating-point value and write it to buffer. Returns a slice to the buffer containing
/// the string representation.
///
/// Full precision is the default. Any full precision float can be reparsed with std.fmt.parseFloat
/// unambiguously.
///
/// Scientific mode is recommended generally as the output is more compact and any type can be
/// written in full precision using a buffer of only `min_buffer_size`.
///
/// When printing full precision decimals, use `bufferSize` to get the required space. It is
/// recommended to bound decimal output with a fixed precision to reduce the required buffer size.
pub fn formatFloat(buf: []u8, v_: anytype, options: FormatOptions) FormatError![]const u8 {
    const v = switch (@TypeOf(v_)) {
        // comptime_float internally is a f128; this preserves precision.
        comptime_float => @as(f128, v_),
        else => v_,
    };

    const T = @TypeOf(v);
    comptime std.debug.assert(@typeInfo(T) == .Float);
    const I = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = @bitSizeOf(T) } });

    const has_explicit_leading_bit = std.math.floatMantissaBits(T) - std.math.floatFractionalBits(T) != 0;
    const d = binaryToDecimal(@as(I, @bitCast(v)), std.math.floatMantissaBits(T), std.math.floatExponentBits(T), has_explicit_leading_bit);

    return switch (options.mode) {
        .scientific => formatScientific(buf, d, options.precision),
        .decimal => formatDecimal(buf, d, options.precision),
    };
}

pub const FloatDecimal128 = struct {
    mantissa: u128,
    exponent: i32,
    sign: bool,
};

fn copySpecialStr(buf: []u8, f: FloatDecimal128) []const u8 {
    if (f.sign) {
        buf[0] = '-';
    }
    const offset: usize = @intFromBool(f.sign);
    if (f.mantissa != 0) {
        @memcpy(buf[offset..][0..3], "nan");
        return buf[0 .. 3 + offset];
    }
    @memcpy(buf[offset..][0..3], "inf");
    return buf[0 .. 3 + offset];
}

fn writeDecimal(buf: []u8, value: anytype, count: usize) void {
    var i: usize = 0;

    while (i + 2 < count) : (i += 2) {
        const c: u8 = @intCast(value.* % 100);
        value.* /= 100;
        const d = std.fmt.digits2(c);
        buf[count - i - 1] = d[1];
        buf[count - i - 2] = d[0];
    }

    while (i < count) : (i += 1) {
        const c: u8 = @intCast(value.* % 10);
        value.* /= 10;
        buf[count - i - 1] = '0' + c;
    }
}

fn isPowerOf10(n_: u128) bool {
    var n = n_;
    while (n != 0) : (n /= 10) {
        if (n % 10 != 0) return false;
    }
    return true;
}

const RoundMode = enum {
    /// 1234.56 = precision 2
    decimal,
    /// 1.23456e3 = precision 5
    scientific,
};

fn round(f: FloatDecimal128, mode: RoundMode, precision: usize) FloatDecimal128 {
    var round_digit: usize = 0;
    var output = f.mantissa;
    var exp = f.exponent;
    const olength = decimalLength(output);

    switch (mode) {
        .decimal => {
            if (f.exponent > 0) {
                round_digit = (olength - 1) + precision + @as(usize, @intCast(f.exponent));
            } else {
                const min_exp_required = @as(usize, @intCast(-f.exponent));
                if (precision + olength > min_exp_required) {
                    round_digit = precision + olength - min_exp_required;
                }
            }
        },
        .scientific => {
            round_digit = 1 + precision;
        },
    }

    if (round_digit < olength) {
        var nlength = olength;
        for (round_digit + 1..olength) |_| {
            output /= 10;
            exp += 1;
            nlength -= 1;
        }

        if (output % 10 >= 5) {
            output /= 10;
            output += 1;
            exp += 1;

            // e.g. 9999 -> 10000
            if (isPowerOf10(output)) {
                output /= 10;
                exp += 1;
            }
        }
    }

    return .{
        .mantissa = output,
        .exponent = exp,
        .sign = f.sign,
    };
}

/// Write a FloatDecimal128 to a buffer in scientific form.
///
/// The buffer provided must be greater than `min_buffer_size` in length. If no precision is
/// specified, this function will never return an error. If a precision is specified, up to
/// `8 + precision` bytes will be written to the buffer. An error will be returned if the content
/// will not fit.
///
/// It is recommended to bound decimal formatting with an exact precision.
pub fn formatScientific(buf: []u8, f_: FloatDecimal128, precision: ?usize) FormatError![]const u8 {
    std.debug.assert(buf.len >= min_buffer_size);
    var f = f_;

    if (f.exponent == special_exponent) {
        return copySpecialStr(buf, f);
    }

    if (precision) |prec| {
        f = round(f, .scientific, prec);
    }

    var output = f.mantissa;
    const olength = decimalLength(output);

    if (precision) |prec| {
        // fixed bound: sign(1) + leading_digit(1) + point(1) + exp_sign(1) + exp_max(4)
        const req_bytes = 8 + prec;
        if (buf.len < req_bytes) {
            return error.BufferTooSmall;
        }
    }

    // Step 5: Print the scientific representation
    var index: usize = 0;
    if (f.sign) {
        buf[index] = '-';
        index += 1;
    }

    // 1.12345
    writeDecimal(buf[index + 2 ..], &output, olength - 1);
    buf[index] = '0' + @as(u8, @intCast(output % 10));
    buf[index + 1] = '.';
    index += 2;
    const dp_index = index;
    if (olength > 1) index += olength - 1 else index -= 1;

    if (precision) |prec| {
        index += @intFromBool(olength == 1);
        if (prec > olength - 1) {
            const len = prec - (olength - 1);
            @memset(buf[index..][0..len], '0');
            index += len;
        } else {
            index = dp_index + prec - @intFromBool(prec == 0);
        }
    }

    // e100
    buf[index] = 'e';
    index += 1;
    var exp = f.exponent + @as(i32, @intCast(olength)) - 1;
    if (exp < 0) {
        buf[index] = '-';
        index += 1;
        exp = -exp;
    }
    var uexp: u32 = @intCast(exp);
    const elength = decimalLength(uexp);
    writeDecimal(buf[index..], &uexp, elength);
    index += elength;

    return buf[0..index];
}

/// Write a FloatDecimal128 to a buffer in decimal form.
///
/// The buffer provided must be greater than `min_buffer_size` bytes in length. If no precision is
/// specified, this may still return an error. If precision is specified, `2 + precision` bytes will
/// always be written.
pub fn formatDecimal(buf: []u8, f_: FloatDecimal128, precision: ?usize) FormatError![]const u8 {
    std.debug.assert(buf.len >= min_buffer_size);
    var f = f_;

    if (f.exponent == special_exponent) {
        return copySpecialStr(buf, f);
    }

    if (precision) |prec| {
        f = round(f, .decimal, prec);
    }

    var output = f.mantissa;
    const olength = decimalLength(output);

    // fixed bound: leading_digit(1) + point(1)
    const req_bytes = if (f.exponent >= 0)
        @as(usize, 2) + @abs(f.exponent) + olength + (precision orelse 0)
    else
        @as(usize, 2) + @max(@abs(f.exponent) + olength, precision orelse 0);
    if (buf.len < req_bytes) {
        return error.BufferTooSmall;
    }

    // Step 5: Print the decimal representation
    var index: usize = 0;
    if (f.sign) {
        buf[index] = '-';
        index += 1;
    }

    const dp_offset = f.exponent + cast_i32(olength);
    if (dp_offset <= 0) {
        // 0.000001234
        buf[index] = '0';
        buf[index + 1] = '.';
        index += 2;
        const dp_index = index;

        const dp_poffset: u32 = @intCast(-dp_offset);
        @memset(buf[index..][0..dp_poffset], '0');
        index += dp_poffset;
        writeDecimal(buf[index..], &output, olength);
        index += olength;

        if (precision) |prec| {
            const dp_written = index - dp_index;
            if (prec > dp_written) {
                @memset(buf[index..][0 .. prec - dp_written], '0');
            }
            index = dp_index + prec - @intFromBool(prec == 0);
        }
    } else {
        // 123456000
        const dp_uoffset: usize = @intCast(dp_offset);
        if (dp_uoffset >= olength) {
            writeDecimal(buf[index..], &output, olength);
            index += olength;
            @memset(buf[index..][0 .. dp_uoffset - olength], '0');
            index += dp_uoffset - olength;

            if (precision) |prec| {
                if (prec != 0) {
                    buf[index] = '.';
                    index += 1;
                    @memset(buf[index..][0..prec], '0');
                    index += prec;
                }
            }
        } else {
            // 12345.6789
            writeDecimal(buf[index + dp_uoffset + 1 ..], &output, olength - dp_uoffset);
            buf[index + dp_uoffset] = '.';
            const dp_index = index + dp_uoffset + 1;
            writeDecimal(buf[index..], &output, dp_uoffset);
            index += olength + 1;

            if (precision) |prec| {
                const dp_written = olength - dp_uoffset;
                if (prec > dp_written) {
                    @memset(buf[index..][0 .. prec - dp_written], '0');
                }
                index = dp_index + prec - @intFromBool(prec == 0);
            }
        }
    }

    return buf[0..index];
}

fn cast_i32(v: anytype) i32 {
    return @intCast(v);
}

/// Convert a binary float representation to decimal.
pub fn binaryToDecimal(bits: u128, mantissa_bits: u7, exponent_bits: u5, explicit_leading_bit: bool) FloatDecimal128 {
    const bias = (@as(u32, 1) << (exponent_bits - 1)) - 1;
    const ieee_sign = ((bits >> (mantissa_bits + exponent_bits)) & 1) != 0;
    const ieee_mantissa = bits & ((@as(u128, 1) << mantissa_bits) - 1);
    const ieee_exponent: u32 = @intCast((bits >> mantissa_bits) & ((@as(u128, 1) << exponent_bits) - 1));

    if (ieee_exponent == 0 and ieee_mantissa == 0) {
        return .{
            .mantissa = 0,
            .exponent = 0,
            .sign = ieee_sign,
        };
    }
    if (ieee_exponent == ((@as(u32, 1) << exponent_bits) - 1)) {
        return .{
            .mantissa = if (explicit_leading_bit) ieee_mantissa & ((@as(u128, 1) << (mantissa_bits - 1)) - 1) else ieee_mantissa,
            .exponent = 0x7fffffff,
            .sign = ieee_sign,
        };
    }

    var e2: i32 = undefined;
    var m2: u128 = undefined;
    if (explicit_leading_bit) {
        if (ieee_exponent == 0) {
            e2 = 1 - cast_i32(bias) - cast_i32(mantissa_bits) + 1 - 2;
        } else {
            e2 = cast_i32(ieee_exponent) - cast_i32(bias) - cast_i32(mantissa_bits) + 1 - 2;
        }
        m2 = ieee_mantissa;
    } else {
        if (ieee_exponent == 0) {
            e2 = 1 - cast_i32(bias) - cast_i32(mantissa_bits) - 2;
            m2 = ieee_mantissa;
        } else {
            e2 = cast_i32(ieee_exponent) - cast_i32(bias) - cast_i32(mantissa_bits) - 2;
            m2 = (@as(u128, 1) << mantissa_bits) | ieee_mantissa;
        }
    }
    const even = (m2 & 1) == 0;
    const accept_bounds = even;

    // Step 2: Determine the interval of legal decimal representations.
    const mv = 4 * m2;
    const mm_shift: u1 = @intFromBool((ieee_mantissa != if (explicit_leading_bit) (@as(u128, 1) << (mantissa_bits - 1)) else 0) or (ieee_exponent == 0));

    // Step 3: Convert to a decimal power base using 128-bit arithmetic.
    var vr: u128 = undefined;
    var vp: u128 = undefined;
    var vm: u128 = undefined;
    var e10: i32 = undefined;
    var vm_is_trailing_zeros = false;
    var vr_is_trailing_zeros = false;
    if (e2 >= 0) {
        const q: u32 = log10Pow2(@intCast(e2)) - @intFromBool(e2 > 3);
        e10 = cast_i32(q);
        const k: i32 = @intCast(FLOAT_128_POW5_INV_BITCOUNT + pow5Bits(q) - 1);
        const i: u32 = @intCast(-e2 + cast_i32(q) + k);

        const pow5 = computeInvPow5(q);
        vr = mulShift(4 * m2, &pow5, i);
        vp = mulShift(4 * m2 + 2, &pow5, i);
        vm = mulShift(4 * m2 - 1 - mm_shift, &pow5, i);

        if (q <= 55) {
            if (mv % 5 == 0) {
                vr_is_trailing_zeros = multipleOfPowerOf5(mv, q -% 1);
            } else if (accept_bounds) {
                vm_is_trailing_zeros = multipleOfPowerOf5(mv - 1 - mm_shift, q);
            } else {
                vp -= @intFromBool(multipleOfPowerOf5(mv + 2, q));
            }
        }
    } else {
        const q: u32 = log10Pow5(@intCast(-e2)) - @intFromBool(-e2 > 1);
        e10 = cast_i32(q) + e2;
        const i: i32 = -e2 - cast_i32(q);
        const k: i32 = cast_i32(pow5Bits(@intCast(i))) - FLOAT_128_POW5_BITCOUNT;
        const j: u32 = @intCast(cast_i32(q) - k);

        const pow5 = computePow5(@intCast(i));
        vr = mulShift(4 * m2, &pow5, j);
        vp = mulShift(4 * m2 + 2, &pow5, j);
        vm = mulShift(4 * m2 - 1 - mm_shift, &pow5, j);

        if (q <= 1) {
            vr_is_trailing_zeros = true;
            if (accept_bounds) {
                vm_is_trailing_zeros = mm_shift == 1;
            } else {
                vp -= 1;
            }
        } else if (q < 127) {
            vr_is_trailing_zeros = multipleOfPowerOf2(mv, q - 1);
        }
    }

    // Step 4: Find the shortest decimal representation in the interval of legal representations.
    var removed: u32 = 0;
    var last_removed_digit: u8 = 0;

    while (vp / 10 > vm / 10) {
        vm_is_trailing_zeros = vm_is_trailing_zeros and vm % 10 == 0;
        vr_is_trailing_zeros = vr_is_trailing_zeros and last_removed_digit == 0;
        last_removed_digit = @intCast(vr % 10);
        vr /= 10;
        vp /= 10;
        vm /= 10;
        removed += 1;
    }

    if (vm_is_trailing_zeros) {
        while (vm % 10 == 0) {
            vr_is_trailing_zeros = vr_is_trailing_zeros and last_removed_digit == 0;
            last_removed_digit = @intCast(vr % 10);
            vr /= 10;
            vp /= 10;
            vm /= 10;
            removed += 1;
        }
    }

    if (vr_is_trailing_zeros and (last_removed_digit == 5) and (vr % 2 == 0)) {
        last_removed_digit = 4;
    }

    return .{
        .mantissa = vr + @intFromBool((vr == vm and (!accept_bounds or !vm_is_trailing_zeros)) or last_removed_digit >= 5),
        .exponent = e10 + cast_i32(removed),
        .sign = ieee_sign,
    };
}

fn decimalLength(v: u128) u32 {
    const LARGEST_POW10 = (@as(u128, 5421010862427522170) << 64) | 687399551400673280;
    var p10 = LARGEST_POW10;
    var i: u32 = 39;
    while (i > 0) : (i -= 1) {
        if (v >= p10) return i;
        p10 /= 10;
    }
    return 1;
}

// floor(log_10(2^e))
fn log10Pow2(e: u32) u32 {
    std.debug.assert(e <= 1 << 15);
    return @intCast((@as(u64, @intCast(e)) * 169464822037455) >> 49);
}

// floor(log_10(5^e))
fn log10Pow5(e: u32) u32 {
    std.debug.assert(e <= 1 << 15);
    return @intCast((@as(u64, @intCast(e)) * 196742565691928) >> 48);
}

// if (e == 0) 1 else ceil(log_2(5^e))
fn pow5Bits(e: u32) u32 {
    std.debug.assert(e <= 1 << 15);
    return @intCast(((@as(u64, @intCast(e)) * 163391164108059) >> 46) + 1);
}

fn pow5Factor(value_: u128) u32 {
    var count: u32 = 0;
    var value = value_;
    while (value > 0) : ({
        count += 1;
        value /= 5;
    }) {
        if (value % 5 != 0) return count;
    }
    return 0;
}

fn multipleOfPowerOf5(value: u128, p: u32) bool {
    return pow5Factor(value) >= p;
}

fn multipleOfPowerOf2(value: u128, p: u32) bool {
    return (value & ((@as(u128, 1) << @as(u7, @intCast(p))) - 1)) == 0;
}

fn computeInvPow5(i: u32) [4]u64 {
    const base = (i + POW5_TABLE_SIZE - 1) / POW5_TABLE_SIZE;
    const base2 = base * POW5_TABLE_SIZE;
    const mul = &GENERIC_POW5_INV_SPLIT[base]; // 1 / 5^base2
    if (i == base2) {
        return .{ mul[0] + 1, mul[1], mul[2], mul[3] };
    } else {
        const offset = base2 - i;
        const m = &GENERIC_POW5_TABLE[offset]; // 5^offset
        const delta = pow5Bits(base2) - pow5Bits(i);

        const shift: u6 = @intCast(2 * (i % 32));
        const corr: u32 = @intCast(((POW5_INV_ERRORS[i / 32] >> shift) & 3) + 1);
        return mul_128_256_shift(m, mul, delta, corr);
    }
}

fn computePow5(i: u32) [4]u64 {
    const base = i / POW5_TABLE_SIZE;
    const base2 = base * POW5_TABLE_SIZE;
    const mul = &GENERIC_POW5_SPLIT[base];
    if (i == base2) {
        return mul.*;
    } else {
        const offset = i - base2;
        const m = &GENERIC_POW5_TABLE[offset];
        const delta = pow5Bits(i) - pow5Bits(base2);

        const shift: u6 = @intCast(2 * (i % 32));
        const corr: u32 = @intCast((POW5_ERRORS[i / 32] >> shift) & 3);
        return mul_128_256_shift(m, mul, delta, corr);
    }
}

fn mulShift(m: u128, mul: *const [4]u64, j: u32) u128 {
    std.debug.assert(j > 128);
    const a: [2]u64 = .{ @truncate(m), @truncate(m >> 64) };
    const r = mul_128_256_shift(&a, mul, j, 0);
    return (@as(u128, r[1]) << 64) | r[0];
}

fn mul_128_256_shift(a: *const [2]u64, b: *const [4]u64, shift: u32, corr: u32) [4]u64 {
    std.debug.assert(shift > 0);
    std.debug.assert(shift < 256);

    const b00 = @as(u128, a[0]) * b[0];
    const b01 = @as(u128, a[0]) * b[1];
    const b02 = @as(u128, a[0]) * b[2];
    const b03 = @as(u128, a[0]) * b[3];
    const b10 = @as(u128, a[1]) * b[0];
    const b11 = @as(u128, a[1]) * b[1];
    const b12 = @as(u128, a[1]) * b[2];
    const b13 = @as(u128, a[1]) * b[3];

    const s0 = b00;
    const s1 = b01 +% b10;
    const c1: u128 = @intFromBool(s1 < b01);
    const s2 = b02 +% b11;
    const c2: u128 = @intFromBool(s2 < b02);
    const s3 = b03 +% b12;
    const c3: u128 = @intFromBool(s3 < b03);

    const p0 = s0 +% (s1 << 64);
    const d0: u128 = @intFromBool(p0 < b00);
    const q1 = s2 +% (s1 >> 64) +% (s3 << 64);
    const d1: u128 = @intFromBool(q1 < s2);
    const p1 = q1 +% (c1 << 64) +% d0;
    const d2: u128 = @intFromBool(p1 < q1);
    const p2 = b13 +% (s3 >> 64) +% c2 +% (c3 << 64) +% d1 +% d2;

    var r0: u128 = undefined;
    var r1: u128 = undefined;
    if (shift < 128) {
        const cshift: u7 = @intCast(shift);
        const sshift: u7 = @intCast(128 - shift);
        r0 = corr +% ((p0 >> cshift) | (p1 << sshift));
        r1 = ((p1 >> cshift) | (p2 << sshift)) +% @intFromBool(r0 < corr);
    } else if (shift == 128) {
        r0 = corr +% p1;
        r1 = p2 +% @intFromBool(r0 < corr);
    } else {
        const ashift: u7 = @intCast(shift - 128);
        const sshift: u7 = @intCast(256 - shift);
        r0 = corr +% ((p1 >> ashift) | (p2 << sshift));
        r1 = (p2 >> ashift) +% @intFromBool(r0 < corr);
    }

    return .{ @truncate(r0), @truncate(r0 >> 64), @truncate(r1), @truncate(r1 >> 64) };
}

// zig fmt: off
//
// 4.5KiB of tables.

const FLOAT_128_POW5_INV_BITCOUNT = 249;
const FLOAT_128_POW5_BITCOUNT = 249;
const POW5_TABLE_SIZE = 56;

const GENERIC_POW5_TABLE: [POW5_TABLE_SIZE][2]u64 = .{
 .{                    1,                    0 },
 .{                    5,                    0 },
 .{                   25,                    0 },
 .{                  125,                    0 },
 .{                  625,                    0 },
 .{                 3125,                    0 },
 .{                15625,                    0 },
 .{                78125,                    0 },
 .{               390625,                    0 },
 .{              1953125,                    0 },
 .{              9765625,                    0 },
 .{             48828125,                    0 },
 .{            244140625,                    0 },
 .{           1220703125,                    0 },
 .{           6103515625,                    0 },
 .{          30517578125,                    0 },
 .{         152587890625,                    0 },
 .{         762939453125,                    0 },
 .{        3814697265625,                    0 },
 .{       19073486328125,                    0 },
 .{       95367431640625,                    0 },
 .{      476837158203125,                    0 },
 .{     2384185791015625,                    0 },
 .{    11920928955078125,                    0 },
 .{    59604644775390625,                    0 },
 .{   298023223876953125,                    0 },
 .{  1490116119384765625,                    0 },
 .{  7450580596923828125,                    0 },
 .{   359414837200037393,                    2 },
 .{  1797074186000186965,                   10 },
 .{  8985370930000934825,                   50 },
 .{  8033366502585570893,                  252 },
 .{  3273344365508751233,                 1262 },
 .{ 16366721827543756165,                 6310 },
 .{  8046632842880574361,                31554 },
 .{  3339676066983768573,               157772 },
 .{ 16698380334918842865,               788860 },
 .{  9704925379756007861,              3944304 },
 .{ 11631138751360936073,             19721522 },
 .{  2815461535676025517,             98607613 },
 .{ 14077307678380127585,            493038065 },
 .{ 15046306170771983077,           2465190328 },
 .{  1444554559021708921,          12325951644 },
 .{  7222772795108544605,          61629758220 },
 .{ 17667119901833171409,         308148791101 },
 .{ 14548623214327650581,        1540743955509 },
 .{ 17402883850509598057,        7703719777548 },
 .{ 13227442957709783821,       38518598887744 },
 .{ 10796982567420264257,      192592994438723 },
 .{ 17091424689682218053,      962964972193617 },
 .{ 11670147153572883801,     4814824860968089 },
 .{  3010503546735764157,    24074124304840448 },
 .{ 15052517733678820785,   120370621524202240 },
 .{  1475612373555897461,   601853107621011204 },
 .{  7378061867779487305,  3009265538105056020 },
 .{ 18443565265187884909, 15046327690525280101 },
};

const GENERIC_POW5_SPLIT: [89][4]u64 = .{
 .{                    0,                    0,                    0,    72057594037927936 },
 .{                    0,  5206161169240293376,  4575641699882439235,    73468396926392969 },
 .{  3360510775605221349,  6983200512169538081,  4325643253124434363,    74906821675075173 },
 .{ 11917660854915489451,  9652941469841108803,   946308467778435600,    76373409087490117 },
 .{  1994853395185689235, 16102657350889591545,  6847013871814915412,    77868710555449746 },
 .{   958415760277438274, 15059347134713823592,  7329070255463483331,    79393288266368765 },
 .{  2065144883315240188,  7145278325844925976, 14718454754511147343,    80947715414629833 },
 .{  8980391188862868935, 13709057401304208685,  8230434828742694591,    82532576417087045 },
 .{   432148644612782575,  7960151582448466064, 12056089168559840552,    84148467132788711 },
 .{   484109300864744403, 15010663910730448582, 16824949663447227068,    85795995087002057 },
 .{ 14793711725276144220, 16494403799991899904, 10145107106505865967,    87475779699624060 },
 .{ 15427548291869817042, 12330588654550505203, 13980791795114552342,    89188452518064298 },
 .{  9979404135116626552, 13477446383271537499, 14459862802511591337,    90934657454687378 },
 .{ 12385121150303452775,  9097130814231585614,  6523855782339765207,    92715051028904201 },
 .{  1822931022538209743, 16062974719797586441,  3619180286173516788,    94530302614003091 },
 .{ 12318611738248470829, 13330752208259324507, 10986694768744162601,    96381094688813589 },
 .{ 13684493829640282333,  7674802078297225834, 15208116197624593182,    98268123094297527 },
 .{  5408877057066295332,  6470124174091971006, 15112713923117703147,   100192097295163851 },
 .{ 11407083166564425062, 18189998238742408185,  4337638702446708282,   102153740646605557 },
 .{  4112405898036935485,   924624216579956435, 14251108172073737125,   104153790666259019 },
 .{ 16996739107011444789, 10015944118339042475,  2395188869672266257,   106192999311487969 },
 .{  4588314690421337879,  5339991768263654604, 15441007590670620066,   108272133262096356 },
 .{  2286159977890359825, 14329706763185060248,  5980012964059367667,   110391974208576409 },
 .{  9654767503237031099, 11293544302844823188, 11739932712678287805,   112553319146000238 },
 .{ 11362964448496095896,  7990659682315657680,   251480263940996374,   114756980673665505 },
 .{  1423410421096377129, 14274395557581462179, 16553482793602208894,   117003787300607788 },
 .{  2070444190619093137, 11517140404712147401, 11657844572835578076,   119294583757094535 },
 .{  7648316884775828921, 15264332483297977688,   247182277434709002,   121630231312217685 },
 .{ 17410896758132241352, 10923914482914417070, 13976383996795783649,   124011608097704390 },
 .{  9542674537907272703,  3079432708831728956, 14235189590642919676,   126439609438067572 },
 .{ 10364666969937261816,  8464573184892924210, 12758646866025101190,   128915148187220428 },
 .{ 14720354822146013883, 11480204489231511423,  7449876034836187038,   131439155071681461 },
 .{  1692907053653558553, 17835392458598425233,  1754856712536736598,   134012579040499057 },
 .{  5620591334531458755, 11361776175667106627, 13350215315297937856,   136636387622027174 },
 .{ 17455759733928092601, 10362573084069962561, 11246018728801810510,   139311567287686283 },
 .{  2465404073814044982, 17694822665274381860,  1509954037718722697,   142039123822846312 },
 .{  2152236053329638369, 11202280800589637091, 16388426812920420176,    72410041352485523 },
 .{ 17319024055671609028, 10944982848661280484,  2457150158022562661,    73827744744583080 },
 .{ 17511219308535248024,  5122059497846768077,  2089605804219668451,    75273205100637900 },
 .{ 10082673333144031533, 14429008783411894887, 12842832230171903890,    76746965869337783 },
 .{ 16196653406315961184, 10260180891682904501, 10537411930446752461,    78249581139456266 },
 .{ 15084422041749743389,   234835370106753111, 16662517110286225617,    79781615848172976 },
 .{  8199644021067702606,  3787318116274991885,  7438130039325743106,    81343645993472659 },
 .{ 12039493937039359765,  9773822153580393709,  5945428874398357806,    82936258850702722 },
 .{   984543865091303961,  7975107621689454830,  6556665988501773347,    84560053193370726 },
 .{  9633317878125234244, 16099592426808915028,  9706674539190598200,    86215639518264828 },
 .{  6860695058870476186,  4471839111886709592,  7828342285492709568,    87903640274981819 },
 .{ 14583324717644598331,  4496120889473451238,  5290040788305728466,    89624690099949049 },
 .{ 18093669366515003715, 12879506572606942994, 18005739787089675377,    91379436055028227 },
 .{ 17997493966862379937, 14646222655265145582, 10265023312844161858,    93168537870790806 },
 .{ 12283848109039722318, 11290258077250314935,  9878160025624946825,    94992668194556404 },
 .{  8087752761883078164,  5262596608437575693, 11093553063763274413,    96852512843287537 },
 .{ 15027787746776840781, 12250273651168257752,  9290470558712181914,    98748771061435726 },
 .{ 15003915578366724489,  2937334162439764327,  5404085603526796602,   100682155783835929 },
 .{  5225610465224746757, 14932114897406142027,  2774647558180708010,   102653393903748137 },
 .{ 17112957703385190360, 12069082008339002412,  3901112447086388439,   104663226546146909 },
 .{  4062324464323300238,  3992768146772240329, 15757196565593695724,   106712409346361594 },
 .{  5525364615810306701, 11855206026704935156, 11344868740897365300,   108801712734172003 },
 .{  9274143661888462646,  4478365862348432381, 18010077872551661771,   110931922223466333 },
 .{ 12604141221930060148,  8930937759942591500,  9382183116147201338,   113103838707570263 },
 .{ 14513929377491886653,  1410646149696279084,   587092196850797612,   115318278760358235 },
 .{  2226851524999454362,  7717102471110805679,  7187441550995571734,   117576074943260147 },
 .{  5527526061344932763,  2347100676188369132, 16976241418824030445,   119878076118278875 },
 .{  6088479778147221611, 17669593130014777580, 10991124207197663546,   122225147767136307 },
 .{ 11107734086759692041,  3391795220306863431, 17233960908859089158,   124618172316667879 },
 .{  7913172514655155198, 17726879005381242552,   641069866244011540,   127058049470587962 },
 .{ 12596991768458713949, 15714785522479904446,  6035972567136116512,   129545696547750811 },
 .{ 16901996933781815980,  4275085211437148707, 14091642539965169063,   132082048827034281 },
 .{  7524574627987869240, 15661204384239316051,  2444526454225712267,   134668059898975949 },
 .{  8199251625090479942,  6803282222165044067, 16064817666437851504,   137304702024293857 },
 .{  4453256673338111920, 15269922543084434181,  3139961729834750852,   139992966499426682 },
 .{ 15841763546372731299,  3013174075437671812,  4383755396295695606,   142733864029230733 },
 .{  9771896230907310329,  4900659362437687569, 12386126719044266361,    72764212553486967 },
 .{  9420455527449565190,  1859606122611023693,  6555040298902684281,    74188850200884818 },
 .{  5146105983135678095,  2287300449992174951,  4325371679080264751,    75641380576797959 },
 .{ 11019359372592553360,  8422686425957443718,  7175176077944048210,    77122349788024458 },
 .{ 11005742969399620716,  4132174559240043701,  9372258443096612118,    78632314633490790 },
 .{  8887589641394725840,  8029899502466543662, 14582206497241572853,    80171842813591127 },
 .{   360247523705545899, 12568341805293354211, 14653258284762517866,    81741513143625247 },
 .{ 12314272731984275834,  4740745023227177044,  6141631472368337539,    83341915771415304 },
 .{   441052047733984759,  7940090120939869826, 11750200619921094248,    84973652399183278 },
 .{  3436657868127012749,  9187006432149937667, 16389726097323041290,    86637336509772529 },
 .{ 13490220260784534044, 15339072891382896702,  8846102360835316895,    88333593597298497 },
 .{  4125672032094859833,   158347675704003277, 10592598512749774447,    90063061402315272 },
 .{ 12189928252974395775,  2386931199439295891,  7009030566469913276,    91826390151586454 },
 .{  9256479608339282969,  2844900158963599229, 11148388908923225596,    93624242802550437 },
 .{ 11584393507658707408,  2863659090805147914,  9873421561981063551,    95457295292572042 },
 .{ 13984297296943171390,  1931468383973130608, 12905719743235082319,    97326236793074198 },
 .{  5837045222254987499, 10213498696735864176, 14893951506257020749,    99231769968645227 },
};

// Unfortunately, the results are sometimes off by one or two. We use an additional
// lookup table to store those cases and adjust the result.
const POW5_ERRORS: [156]u64 = .{
 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x9555596400000000,
 0x65a6569525565555, 0x4415551445449655, 0x5105015504144541, 0x65a69969a6965964,
 0x5054955969959656, 0x5105154515554145, 0x4055511051591555, 0x5500514455550115,
 0x0041140014145515, 0x1005440545511051, 0x0014405450411004, 0x0414440010500000,
 0x0044000440010040, 0x5551155000004001, 0x4554555454544114, 0x5150045544005441,
 0x0001111400054501, 0x6550955555554554, 0x1504159645559559, 0x4105055141454545,
 0x1411541410405454, 0x0415555044545555, 0x0014154115405550, 0x1540055040411445,
 0x0000000500000000, 0x5644000000000000, 0x1155555591596555, 0x0410440054569565,
 0x5145100010010005, 0x0555041405500150, 0x4141450455140450, 0x0000000144000140,
 0x5114004001105410, 0x4444100404005504, 0x0414014410001015, 0x5145055155555015,
 0x0141041444445540, 0x0000100451541414, 0x4105041104155550, 0x0500501150451145,
 0x1001050000004114, 0x5551504400141045, 0x5110545410151454, 0x0100001400004040,
 0x5040010111040000, 0x0140000150541100, 0x4400140400104110, 0x5011014405545004,
 0x0000000044155440, 0x0000000010000000, 0x1100401444440001, 0x0040401010055111,
 0x5155155551405454, 0x0444440015514411, 0x0054505054014101, 0x0451015441115511,
 0x1541411401140551, 0x4155104514445110, 0x4141145450145515, 0x5451445055155050,
 0x4400515554110054, 0x5111145104501151, 0x565a655455500501, 0x5565555555525955,
 0x0550511500405695, 0x4415504051054544, 0x6555595965555554, 0x0100915915555655,
 0x5540001510001001, 0x5450051414000544, 0x1405010555555551, 0x5555515555644155,
 0x5555055595496555, 0x5451045004415000, 0x5450510144040144, 0x5554155555556455,
 0x5051555495415555, 0x5555554555555545, 0x0000000010005455, 0x4000005000040000,
 0x5565555555555954, 0x5554559555555505, 0x9645545495552555, 0x4000400055955564,
 0x0040000000000001, 0x4004100100000000, 0x5540040440000411, 0x4565555955545644,
 0x1140659549651556, 0x0100000410010000, 0x5555515400004001, 0x5955545555155255,
 0x5151055545505556, 0x5051454510554515, 0x0501500050415554, 0x5044154005441005,
 0x1455445450550455, 0x0010144055144545, 0x0000401100000004, 0x1050145050000010,
 0x0415004554011540, 0x1000510100151150, 0x0100040400001144, 0x0000000000000000,
 0x0550004400000100, 0x0151145041451151, 0x0000400400005450, 0x0000100044010004,
 0x0100054100050040, 0x0504400005410010, 0x4011410445500105, 0x0000404000144411,
 0x0101504404500000, 0x0000005044400400, 0x0000000014000100, 0x0404440414000000,
 0x5554100410000140, 0x4555455544505555, 0x5454105055455455, 0x0115454155454015,
 0x4404110000045100, 0x4400001100101501, 0x6596955956966a94, 0x0040655955665965,
 0x5554144400100155, 0xa549495401011041, 0x5596555565955555, 0x5569965959549555,
 0x969565a655555456, 0x0000001000000000, 0x0000000040000140, 0x0000040100000000,
 0x1415454400000000, 0x5410415411454114, 0x0400040104000154, 0x0504045000000411,
 0x0000001000000010, 0x5554000000001040, 0x5549155551556595, 0x1455541055515555,
 0x0510555454554541, 0x9555555555540455, 0x6455456555556465, 0x4524565555654514,
 0x5554655255559545, 0x9555455441155556, 0x0000000051515555, 0x0010005040000550,
 0x5044044040000000, 0x1045040440010500, 0x0000400000040000, 0x0000000000000000,
};

const GENERIC_POW5_INV_SPLIT: [89][4]u64 = .{
 .{                    0,                    0,                    0,   144115188075855872 },
 .{  1573859546583440065,  2691002611772552616,  6763753280790178510,   141347765182270746 },
 .{ 12960290449513840412, 12345512957918226762, 18057899791198622765,   138633484706040742 },
 .{  7615871757716765416,  9507132263365501332,  4879801712092008245,   135971326161092377 },
 .{  7869961150745287587,  5804035291554591636,  8883897266325833928,   133360288657597085 },
 .{  2942118023529634767, 15128191429820565086, 10638459445243230718,   130799390525667397 },
 .{ 14188759758411913794,  5362791266439207815,  8068821289119264054,   128287668946279217 },
 .{  7183196927902545212,  1952291723540117099, 12075928209936341512,   125824179589281448 },
 .{  5672588001402349748, 17892323620748423487,  9874578446960390364,   123407996258356868 },
 .{  4442590541217566325,  4558254706293456445, 10343828952663182727,   121038210542800766 },
 .{  3005560928406962566,  2082271027139057888, 13961184524927245081,   118713931475986426 },
 .{ 13299058168408384786, 17834349496131278595,  9029906103900731664,   116434285200389047 },
 .{  5414878118283973035, 13079825470227392078, 17897304791683760280,   114198414639042157 },
 .{ 14609755883382484834, 14991702445765844156,  3269802549772755411,   112005479173303009 },
 .{ 15967774957605076027,  2511532636717499923, 16221038267832563171,   109854654326805788 },
 .{  9269330061621627145,  3332501053426257392, 16223281189403734630,   107745131455483836 },
 .{ 16739559299223642282,  1873986623300664530,  6546709159471442872,   105676117443544318 },
 .{ 17116435360051202055,  1359075105581853924,  2038341371621886470,   103646834405281051 },
 .{ 17144715798009627550,  3201623802661132408,  9757551605154622431,   101656519392613377 },
 .{ 17580479792687825857,  6546633380567327312, 15099972427870912398,    99704424108241124 },
 .{  9726477118325522902, 14578369026754005435, 11728055595254428803,    97789814624307808 },
 .{   134593949518343635,  5715151379816901985,  1660163707976377376,    95911971106466306 },
 .{  5515914027713859358,  7124354893273815720,  5548463282858794077,    94070187543243255 },
 .{  6188403395862945512,  5681264392632320838, 15417410852121406654,    92263771480600430 },
 .{ 15908890877468271457, 10398888261125597540,  4817794962769172309,    90492043761593298 },
 .{  1413077535082201005, 12675058125384151580,  7731426132303759597,    88754338271028867 },
 .{  1486733163972670293, 11369385300195092554, 11610016711694864110,    87050001685026843 },
 .{  8788596583757589684,  3978580923851924802,  9255162428306775812,    85378393225389919 },
 .{  7203518319660962120, 15044736224407683725,  2488132019818199792,    83738884418690858 },
 .{  4004175967662388707, 18236988667757575407, 15613100370957482671,    82130858859985791 },
 .{ 18371903370586036463,    53497579022921640, 16465963977267203307,    80553711981064899 },
 .{ 10170778323887491315,  1999668801648976001, 10209763593579456445,    79006850823153334 },
 .{ 17108131712433974546, 16825784443029944237,  2078700786753338945,    77489693813976938 },
 .{ 17221789422665858532, 12145427517550446164,  5391414622238668005,    76001670549108934 },
 .{  4859588996898795878,  1715798948121313204,  3950858167455137171,    74542221577515387 },
 .{ 13513469241795711526,   631367850494860526, 10517278915021816160,    73110798191218799 },
 .{ 11757513142672073111,  2581974932255022228, 17498959383193606459,   143413724438001539 },
 .{ 14524355192525042817,  5640643347559376447,  1309659274756813016,   140659771648132296 },
 .{  2765095348461978538, 11021111021896007722,  3224303603779962366,   137958702611185230 },
 .{ 12373410389187981037, 13679193545685856195, 11644609038462631561,   135309501808182158 },
 .{ 12813176257562780151,  3754199046160268020,  9954691079802960722,   132711173221007413 },
 .{ 17557452279667723458,  3237799193992485824, 17893947919029030695,   130162739957935629 },
 .{ 14634200999559435155,  4123869946105211004,  6955301747350769239,   127663243886350468 },
 .{  2185352760627740240,  2864813346878886844, 13049218671329690184,   125211745272516185 },
 .{  6143438674322183002, 10464733336980678750,  6982925169933978309,   122807322428266620 },
 .{  1099509117817174576, 10202656147550524081,   754997032816608484,   120449071364478757 },
 .{  2410631293559367023, 17407273750261453804, 15307291918933463037,   118136105451200587 },
 .{ 12224968375134586697,  1664436604907828062, 11506086230137787358,   115867555084305488 },
 .{  3495926216898000888, 18392536965197424288, 10992889188570643156,   113642567358547782 },
 .{  8744506286256259680,  3966568369496879937, 18342264969761820037,   111460305746896569 },
 .{  7689600520560455039,  5254331190877624630,  9628558080573245556,   109319949786027263 },
 .{ 11862637625618819436,  3456120362318976488, 14690471063106001082,   107220694767852583 },
 .{  5697330450030126444, 12424082405392918899,   358204170751754904,   105161751436977040 },
 .{ 11257457505097373622, 15373192700214208870,   671619062372033814,   103142345693961148 },
 .{ 16850355018477166700,  1913910419361963966,  4550257919755970531,   101161718304283822 },
 .{  9670835567561997011, 10584031339132130638,  3060560222974851757,    99219124612893520 },
 .{  7698686577353054710, 11689292838639130817, 11806331021588878241,    97313834264240819 },
 .{ 12233569599615692137,  3347791226108469959, 10333904326094451110,    95445130927687169 },
 .{ 13049400362825383933, 17142621313007799680,  3790542585289224168,    93612312028186576 },
 .{ 12430457242474442072,  5625077542189557960, 14765055286236672238,    91814688482138969 },
 .{  4759444137752473128,  2230562561567025078,  4954443037339580076,    90051584438315940 },
 .{  7246913525170274758,  8910297835195760709,  4015904029508858381,    88322337023761438 },
 .{ 12854430245836432067,  8135139748065431455, 11548083631386317976,    86626296094571907 },
 .{  4848827254502687803,  4789491250196085625,  3988192420450664125,    84962823991462151 },
 .{  7435538409611286684,   904061756819742353, 14598026519493048444,    83331295300025028 },
 .{ 11042616160352530997,  8948390828345326218, 10052651191118271927,    81731096615594853 },
 .{ 11059348291563778943, 11696515766184685544,  3783210511290897367,    80161626312626082 },
 .{  7020010856491885826,  5025093219346041680,  8960210401638911765,    78622294318500592 },
 .{ 17732844474490699984,  7820866704994446502,  6088373186798844243,    77112521891678506 },
 .{   688278527545590501,  3045610706602776618,  8684243536999567610,    75631741404109150 },
 .{  2734573255120657297,  3903146411440697663,  9470794821691856713,    74179396127820347 },
 .{ 15996457521023071259,  4776627823451271680, 12394856457265744744,    72754940025605801 },
 .{ 13492065758834518331,  7390517611012222399,  1630485387832860230,   142715675091463768 },
 .{ 13665021627282055864,  9897834675523659302, 17907668136755296849,   139975126841173266 },
 .{  9603773719399446181, 10771916301484339398, 10672699855989487527,   137287204938390542 },
 .{  3630218541553511265,  8139010004241080614,  2876479648932814543,   134650898807055963 },
 .{  8318835909686377084,  9525369258927993371,  2796120270400437057,   132065217277054270 },
 .{ 11190003059043290163, 12424345635599592110, 12539346395388933763,   129529188211565064 },
 .{  8701968833973242276,   820569587086330727,  2315591597351480110,   127041858141569228 },
 .{  5115113890115690487, 16906305245394587826,  9899749468931071388,   124602291907373862 },
 .{ 15543535488939245974, 10945189844466391399,  3553863472349432246,   122209572307020975 },
 .{  7709257252608325038,  1191832167690640880, 15077137020234258537,   119862799751447719 },
 .{  7541333244210021737,  9790054727902174575,  5160944773155322014,   117561091926268545 },
 .{ 12297384708782857832,  1281328873123467374,  4827925254630475769,   115303583460052092 },
 .{ 13243237906232367265, 15873887428139547641,  3607993172301799599,   113089425598968120 },
 .{ 11384616453739611114, 15184114243769211033, 13148448124803481057,   110917785887682141 },
 .{ 17727970963596660683,  1196965221832671990, 14537830463956404138,   108787847856377790 },
 .{ 17241367586707330931,  8880584684128262874, 11173506540726547818,   106698810713789254 },
 .{  7184427196661305643, 14332510582433188173, 14230167953789677901,   104649889046128358 },
};

const POW5_INV_ERRORS: [154]u64 = .{
 0x1144155514145504, 0x0000541555401141, 0x0000000000000000, 0x0154454000000000,
 0x4114105515544440, 0x0001001111500415, 0x4041411410011000, 0x5550114515155014,
 0x1404100041554551, 0x0515000450404410, 0x5054544401140004, 0x5155501005555105,
 0x1144141000105515, 0x0541500000500000, 0x1104105540444140, 0x4000015055514110,
 0x0054010450004005, 0x4155515404100005, 0x5155145045155555, 0x1511555515440558,
 0x5558544555515555, 0x0000000000000010, 0x5004000000000050, 0x1415510100000010,
 0x4545555444514500, 0x5155151555555551, 0x1441540144044554, 0x5150104045544400,
 0x5450545401444040, 0x5554455045501400, 0x4655155555555145, 0x1000010055455055,
 0x1000004000055004, 0x4455405104000005, 0x4500114504150545, 0x0000000014000000,
 0x5450000000000000, 0x5514551511445555, 0x4111501040555451, 0x4515445500054444,
 0x5101500104100441, 0x1545115155545055, 0x0000000000000000, 0x1554000000100000,
 0x5555545595551555, 0x5555051851455955, 0x5555555555555559, 0x0000400011001555,
 0x0000004400040000, 0x5455511555554554, 0x5614555544115445, 0x6455156145555155,
 0x5455855455415455, 0x5515555144555545, 0x0114400000145155, 0x0000051000450511,
 0x4455154554445100, 0x4554150141544455, 0x65955555559a5965, 0x5555555854559559,
 0x9569654559616595, 0x1040044040005565, 0x1010010500011044, 0x1554015545154540,
 0x4440555401545441, 0x1014441450550105, 0x4545400410504145, 0x5015111541040151,
 0x5145051154000410, 0x1040001044545044, 0x4001400000151410, 0x0540000044040000,
 0x0510555454411544, 0x0400054054141550, 0x1001041145001100, 0x0000000140000000,
 0x0000000014100000, 0x1544005454000140, 0x4050055505445145, 0x0011511104504155,
 0x5505544415045055, 0x1155154445515554, 0x0000000000004555, 0x0000000000000000,
 0x5101010510400004, 0x1514045044440400, 0x5515519555515555, 0x4554545441555545,
 0x1551055955551515, 0x0150000011505515, 0x0044005040400000, 0x0004001004010050,
 0x0000051004450414, 0x0114001101001144, 0x0401000001000001, 0x4500010001000401,
 0x0004100000005000, 0x0105000441101100, 0x0455455550454540, 0x5404050144105505,
 0x4101510540555455, 0x1055541411451555, 0x5451445110115505, 0x1154110010101545,
 0x1145140450054055, 0x5555565415551554, 0x1550559555555555, 0x5555541545045141,
 0x4555455450500100, 0x5510454545554555, 0x1510140115045455, 0x1001050040111510,
 0x5555454555555504, 0x9954155545515554, 0x6596656555555555, 0x0140410051555559,
 0x0011104010001544, 0x965669659a680501, 0x5655a55955556955, 0x4015111014404514,
 0x1414155554505145, 0x0540040011051404, 0x1010000000015005, 0x0010054050004410,
 0x5041104014000100, 0x4440010500100001, 0x1155510504545554, 0x0450151545115541,
 0x4000100400110440, 0x1004440010514440, 0x0000115050450000, 0x0545404455541500,
 0x1051051555505101, 0x5505144554544144, 0x4550545555515550, 0x0015400450045445,
 0x4514155400554415, 0x4555055051050151, 0x1511441450001014, 0x4544554510404414,
 0x4115115545545450, 0x5500541555551555, 0x5550010544155015, 0x0144414045545500,
 0x4154050001050150, 0x5550511111000145, 0x1114504055000151, 0x5104041101451040,
 0x0010501401051441, 0x0010501450504401, 0x4554585440044444, 0x5155555951450455,
 0x0040000400105555, 0x0000000000000001,
};

// zig fmt: on

fn check(comptime T: type, value: T, comptime expected: []const u8) !void {
    const I = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = @bitSizeOf(T) } });

    var buf: [6000]u8 = undefined;
    const value_bits: I = @bitCast(value);
    const s = try formatFloat(&buf, value, .{});
    try std.testing.expectEqualStrings(expected, s);

    if (@bitSizeOf(T) != 80) {
        const o = try std.fmt.parseFloat(T, s);
        const o_bits: I = @bitCast(o);

        if (std.math.isNan(value)) {
            try std.testing.expect(std.math.isNan(o));
        } else {
            try std.testing.expectEqual(value_bits, o_bits);
        }
    }
}

test "format f32" {
    try check(f32, 0.0, "0e0");
    try check(f32, -0.0, "-0e0");
    try check(f32, 1.0, "1e0");
    try check(f32, -1.0, "-1e0");
    try check(f32, std.math.nan(f32), "nan");
    try check(f32, std.math.inf(f32), "inf");
    try check(f32, -std.math.inf(f32), "-inf");
    try check(f32, 1.1754944e-38, "1.1754944e-38");
    try check(f32, @bitCast(@as(u32, 0x7f7fffff)), "3.4028235e38");
    try check(f32, @bitCast(@as(u32, 1)), "1e-45");
    try check(f32, 3.355445E7, "3.355445e7");
    try check(f32, 8.999999e9, "9e9");
    try check(f32, 3.4366717e10, "3.436672e10");
    try check(f32, 3.0540412e5, "3.0540412e5");
    try check(f32, 8.0990312e3, "8.0990312e3");
    try check(f32, 2.4414062e-4, "2.4414062e-4");
    try check(f32, 2.4414062e-3, "2.4414062e-3");
    try check(f32, 4.3945312e-3, "4.3945312e-3");
    try check(f32, 6.3476562e-3, "6.3476562e-3");
    try check(f32, 4.7223665e21, "4.7223665e21");
    try check(f32, 8388608.0, "8.388608e6");
    try check(f32, 1.6777216e7, "1.6777216e7");
    try check(f32, 3.3554436e7, "3.3554436e7");
    try check(f32, 6.7131496e7, "6.7131496e7");
    try check(f32, 1.9310392e-38, "1.9310392e-38");
    try check(f32, -2.47e-43, "-2.47e-43");
    try check(f32, 1.993244e-38, "1.993244e-38");
    try check(f32, 4103.9003, "4.1039004e3");
    try check(f32, 5.3399997e9, "5.3399997e9");
    try check(f32, 6.0898e-39, "6.0898e-39");
    try check(f32, 0.0010310042, "1.0310042e-3");
    try check(f32, 2.8823261e17, "2.882326e17");
    try check(f32, 7.038531e-26, "7.038531e-26");
    try check(f32, 9.2234038e17, "9.223404e17");
    try check(f32, 6.7108872e7, "6.710887e7");
    try check(f32, 1.0e-44, "1e-44");
    try check(f32, 2.816025e14, "2.816025e14");
    try check(f32, 9.223372e18, "9.223372e18");
    try check(f32, 1.5846085e29, "1.5846086e29");
    try check(f32, 1.1811161e19, "1.1811161e19");
    try check(f32, 5.368709e18, "5.368709e18");
    try check(f32, 4.6143165e18, "4.6143166e18");
    try check(f32, 0.007812537, "7.812537e-3");
    try check(f32, 1.4e-45, "1e-45");
    try check(f32, 1.18697724e20, "1.18697725e20");
    try check(f32, 1.00014165e-36, "1.00014165e-36");
    try check(f32, 200.0, "2e2");
    try check(f32, 3.3554432e7, "3.3554432e7");

    try check(f32, 1.0, "1e0");
    try check(f32, 1.2, "1.2e0");
    try check(f32, 1.23, "1.23e0");
    try check(f32, 1.234, "1.234e0");
    try check(f32, 1.2345, "1.2345e0");
    try check(f32, 1.23456, "1.23456e0");
    try check(f32, 1.234567, "1.234567e0");
    try check(f32, 1.2345678, "1.2345678e0");
    try check(f32, 1.23456735e-36, "1.23456735e-36");
}

test "format f64" {
    try check(f64, 0.0, "0e0");
    try check(f64, -0.0, "-0e0");
    try check(f64, 1.0, "1e0");
    try check(f64, -1.0, "-1e0");
    try check(f64, std.math.nan(f64), "nan");
    try check(f64, std.math.inf(f64), "inf");
    try check(f64, -std.math.inf(f64), "-inf");
    try check(f64, 2.2250738585072014e-308, "2.2250738585072014e-308");
    try check(f64, @bitCast(@as(u64, 0x7fefffffffffffff)), "1.7976931348623157e308");
    try check(f64, @bitCast(@as(u64, 1)), "5e-324");
    try check(f64, 2.98023223876953125e-8, "2.9802322387695312e-8");
    try check(f64, -2.109808898695963e16, "-2.109808898695963e16");
    try check(f64, 4.940656e-318, "4.940656e-318");
    try check(f64, 1.18575755e-316, "1.18575755e-316");
    try check(f64, 2.989102097996e-312, "2.989102097996e-312");
    try check(f64, 9.0608011534336e15, "9.0608011534336e15");
    try check(f64, 4.708356024711512e18, "4.708356024711512e18");
    try check(f64, 9.409340012568248e18, "9.409340012568248e18");
    try check(f64, 1.2345678, "1.2345678e0");
    try check(f64, @bitCast(@as(u64, 0x4830f0cf064dd592)), "5.764607523034235e39");
    try check(f64, @bitCast(@as(u64, 0x4840f0cf064dd592)), "1.152921504606847e40");
    try check(f64, @bitCast(@as(u64, 0x4850f0cf064dd592)), "2.305843009213694e40");

    try check(f64, 1, "1e0");
    try check(f64, 1.2, "1.2e0");
    try check(f64, 1.23, "1.23e0");
    try check(f64, 1.234, "1.234e0");
    try check(f64, 1.2345, "1.2345e0");
    try check(f64, 1.23456, "1.23456e0");
    try check(f64, 1.234567, "1.234567e0");
    try check(f64, 1.2345678, "1.2345678e0");
    try check(f64, 1.23456789, "1.23456789e0");
    try check(f64, 1.234567895, "1.234567895e0");
    try check(f64, 1.2345678901, "1.2345678901e0");
    try check(f64, 1.23456789012, "1.23456789012e0");
    try check(f64, 1.234567890123, "1.234567890123e0");
    try check(f64, 1.2345678901234, "1.2345678901234e0");
    try check(f64, 1.23456789012345, "1.23456789012345e0");
    try check(f64, 1.234567890123456, "1.234567890123456e0");
    try check(f64, 1.2345678901234567, "1.2345678901234567e0");

    try check(f64, 4.294967294, "4.294967294e0");
    try check(f64, 4.294967295, "4.294967295e0");
    try check(f64, 4.294967296, "4.294967296e0");
    try check(f64, 4.294967297, "4.294967297e0");
    try check(f64, 4.294967298, "4.294967298e0");
}

test "format f80" {
    try check(f80, 0.0, "0e0");
    try check(f80, -0.0, "-0e0");
    try check(f80, 1.0, "1e0");
    try check(f80, -1.0, "-1e0");
    try check(f80, std.math.nan(f80), "nan");
    try check(f80, std.math.inf(f80), "inf");
    try check(f80, -std.math.inf(f80), "-inf");

    try check(f80, 2.2250738585072014e-308, "2.2250738585072014e-308");
    try check(f80, 2.98023223876953125e-8, "2.98023223876953125e-8");
    try check(f80, -2.109808898695963e16, "-2.109808898695963e16");
    try check(f80, 4.940656e-318, "4.940656e-318");
    try check(f80, 1.18575755e-316, "1.18575755e-316");
    try check(f80, 2.989102097996e-312, "2.989102097996e-312");
    try check(f80, 9.0608011534336e15, "9.0608011534336e15");
    try check(f80, 4.708356024711512e18, "4.708356024711512e18");
    try check(f80, 9.409340012568248e18, "9.409340012568248e18");
    try check(f80, 1.2345678, "1.2345678e0");
}

test "format f128" {
    try check(f128, 0.0, "0e0");
    try check(f128, -0.0, "-0e0");
    try check(f128, 1.0, "1e0");
    try check(f128, -1.0, "-1e0");
    try check(f128, std.math.nan(f128), "nan");
    try check(f128, std.math.inf(f128), "inf");
    try check(f128, -std.math.inf(f128), "-inf");

    try check(f128, 2.2250738585072014e-308, "2.2250738585072014e-308");
    try check(f128, 2.98023223876953125e-8, "2.98023223876953125e-8");
    try check(f128, -2.109808898695963e16, "-2.109808898695963e16");
    try check(f128, 4.940656e-318, "4.940656e-318");
    try check(f128, 1.18575755e-316, "1.18575755e-316");
    try check(f128, 2.989102097996e-312, "2.989102097996e-312");
    try check(f128, 9.0608011534336e15, "9.0608011534336e15");
    try check(f128, 4.708356024711512e18, "4.708356024711512e18");
    try check(f128, 9.409340012568248e18, "9.409340012568248e18");
    try check(f128, 1.2345678, "1.2345678e0");
}

test "format float to decimal with zero precision" {
    try expectFmt("5", "{d:.0}", .{5});
    try expectFmt("6", "{d:.0}", .{6});
    try expectFmt("7", "{d:.0}", .{7});
    try expectFmt("8", "{d:.0}", .{8});
}

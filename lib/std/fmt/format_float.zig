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
    comptime std.debug.assert(@typeInfo(T) == .float);
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
    comptime std.debug.assert(@typeInfo(T) == .float);
    const I = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @bitSizeOf(T) } });

    const DT = if (@bitSizeOf(T) <= 64) u64 else u128;
    const tables = switch (DT) {
        u64 => if (@import("builtin").mode == .ReleaseSmall) &Backend64_TablesSmall else &Backend64_TablesFull,
        u128 => &Backend128_Tables,
        else => unreachable,
    };

    const has_explicit_leading_bit = std.math.floatMantissaBits(T) - std.math.floatFractionalBits(T) != 0;
    const d = binaryToDecimal(DT, @as(I, @bitCast(v)), std.math.floatMantissaBits(T), std.math.floatExponentBits(T), has_explicit_leading_bit, tables);

    return switch (options.mode) {
        .scientific => formatScientific(DT, buf, d, options.precision),
        .decimal => formatDecimal(DT, buf, d, options.precision),
    };
}

pub fn FloatDecimal(comptime T: type) type {
    comptime std.debug.assert(T == u64 or T == u128);
    return struct {
        mantissa: T,
        exponent: i32,
        sign: bool,
    };
}

fn copySpecialStr(buf: []u8, f: anytype) []const u8 {
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

fn round(comptime T: type, f: FloatDecimal(T), mode: RoundMode, precision: usize) FloatDecimal(T) {
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

/// Write a FloatDecimal to a buffer in scientific form.
///
/// The buffer provided must be greater than `min_buffer_size` in length. If no precision is
/// specified, this function will never return an error. If a precision is specified, up to
/// `8 + precision` bytes will be written to the buffer. An error will be returned if the content
/// will not fit.
///
/// It is recommended to bound decimal formatting with an exact precision.
pub fn formatScientific(comptime T: type, buf: []u8, f_: FloatDecimal(T), precision: ?usize) FormatError![]const u8 {
    std.debug.assert(buf.len >= min_buffer_size);
    var f = f_;

    if (f.exponent == special_exponent) {
        return copySpecialStr(buf, f);
    }

    if (precision) |prec| {
        f = round(T, f, .scientific, prec);
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

/// Write a FloatDecimal to a buffer in decimal form.
///
/// The buffer provided must be greater than `min_buffer_size` bytes in length. If no precision is
/// specified, this may still return an error. If precision is specified, `2 + precision` bytes will
/// always be written.
pub fn formatDecimal(comptime T: type, buf: []u8, f_: FloatDecimal(T), precision: ?usize) FormatError![]const u8 {
    std.debug.assert(buf.len >= min_buffer_size);
    var f = f_;

    if (f.exponent == special_exponent) {
        return copySpecialStr(buf, f);
    }

    if (precision) |prec| {
        f = round(T, f, .decimal, prec);
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
pub fn binaryToDecimal(comptime T: type, bits: T, mantissa_bits: std.math.Log2Int(T), exponent_bits: u5, explicit_leading_bit: bool, comptime tables: anytype) FloatDecimal(T) {
    if (T != tables.T) {
        @compileError("table type does not match backend type: " ++ @typeName(tables.T) ++ " != " ++ @typeName(T));
    }

    const bias = (@as(u32, 1) << (exponent_bits - 1)) - 1;
    const ieee_sign = ((bits >> (mantissa_bits + exponent_bits)) & 1) != 0;
    const ieee_mantissa = bits & ((@as(T, 1) << mantissa_bits) - 1);
    const ieee_exponent: u32 = @intCast((bits >> mantissa_bits) & ((@as(T, 1) << exponent_bits) - 1));

    if (ieee_exponent == 0 and ieee_mantissa == 0) {
        return .{
            .mantissa = 0,
            .exponent = 0,
            .sign = ieee_sign,
        };
    }
    if (ieee_exponent == ((@as(u32, 1) << exponent_bits) - 1)) {
        return .{
            .mantissa = if (explicit_leading_bit) ieee_mantissa & ((@as(T, 1) << (mantissa_bits - 1)) - 1) else ieee_mantissa,
            .exponent = special_exponent,
            .sign = ieee_sign,
        };
    }

    var e2: i32 = undefined;
    var m2: T = undefined;
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
            m2 = (@as(T, 1) << mantissa_bits) | ieee_mantissa;
        }
    }
    const even = (m2 & 1) == 0;
    const accept_bounds = even;

    // Step 2: Determine the interval of legal decimal representations.
    const mv = 4 * m2;
    const mm_shift: u1 = @intFromBool((ieee_mantissa != if (explicit_leading_bit) (@as(T, 1) << (mantissa_bits - 1)) else 0) or (ieee_exponent == 0));

    // Step 3: Convert to a decimal power base using 128-bit arithmetic.
    var vr: T = undefined;
    var vp: T = undefined;
    var vm: T = undefined;
    var e10: i32 = undefined;
    var vm_is_trailing_zeros = false;
    var vr_is_trailing_zeros = false;
    if (e2 >= 0) {
        const q: u32 = log10Pow2(@intCast(e2)) - @intFromBool(e2 > 3);
        e10 = cast_i32(q);
        const k: i32 = @intCast(tables.POW5_INV_BITCOUNT + pow5Bits(q) - 1);
        const i: u32 = @intCast(-e2 + cast_i32(q) + k);

        const pow5 = tables.computeInvPow5(q);
        vr = tables.mulShift(4 * m2, &pow5, i);
        vp = tables.mulShift(4 * m2 + 2, &pow5, i);
        vm = tables.mulShift(4 * m2 - 1 - mm_shift, &pow5, i);

        if (q <= tables.bound1) {
            if (mv % 5 == 0) {
                vr_is_trailing_zeros = multipleOfPowerOf5(mv, if (tables.adjust_q) q -% 1 else q);
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
        const k: i32 = cast_i32(pow5Bits(@intCast(i))) - tables.POW5_BITCOUNT;
        const j: u32 = @intCast(cast_i32(q) - k);

        const pow5 = tables.computePow5(@intCast(i));
        vr = tables.mulShift(4 * m2, &pow5, j);
        vp = tables.mulShift(4 * m2 + 2, &pow5, j);
        vm = tables.mulShift(4 * m2 - 1 - mm_shift, &pow5, j);

        if (q <= 1) {
            vr_is_trailing_zeros = true;
            if (accept_bounds) {
                vm_is_trailing_zeros = mm_shift == 1;
            } else {
                vp -= 1;
            }
        } else if (q < tables.bound2) {
            vr_is_trailing_zeros = multipleOfPowerOf2(mv, if (tables.adjust_q) q - 1 else q);
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

fn decimalLength(v: anytype) u32 {
    switch (@TypeOf(v)) {
        u32, u64 => {
            std.debug.assert(v < 100000000000000000);
            if (v >= 10000000000000000) return 17;
            if (v >= 1000000000000000) return 16;
            if (v >= 100000000000000) return 15;
            if (v >= 10000000000000) return 14;
            if (v >= 1000000000000) return 13;
            if (v >= 100000000000) return 12;
            if (v >= 10000000000) return 11;
            if (v >= 1000000000) return 10;
            if (v >= 100000000) return 9;
            if (v >= 10000000) return 8;
            if (v >= 1000000) return 7;
            if (v >= 100000) return 6;
            if (v >= 10000) return 5;
            if (v >= 1000) return 4;
            if (v >= 100) return 3;
            if (v >= 10) return 2;
            return 1;
        },
        u128 => {
            const LARGEST_POW10 = (@as(u128, 5421010862427522170) << 64) | 687399551400673280;
            var p10 = LARGEST_POW10;
            var i: u32 = 39;
            while (i > 0) : (i -= 1) {
                if (v >= p10) return i;
                p10 /= 10;
            }
            return 1;
        },
        else => unreachable,
    }
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

fn pow5Factor(value_: anytype) u32 {
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

fn multipleOfPowerOf5(value: anytype, p: u32) bool {
    const T = @TypeOf(value);
    std.debug.assert(@typeInfo(T) == .int);
    return pow5Factor(value) >= p;
}

fn multipleOfPowerOf2(value: anytype, p: u32) bool {
    const T = @TypeOf(value);
    std.debug.assert(@typeInfo(T) == .int);
    return (value & ((@as(T, 1) << @as(std.math.Log2Int(T), @intCast(p))) - 1)) == 0;
}

fn mulShift128(m: u128, mul: *const [4]u64, j: u32) u128 {
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

pub const Backend128_Tables = struct {
    const T = u128;
    const mulShift = mulShift128;
    const POW5_INV_BITCOUNT = FLOAT128_POW5_INV_BITCOUNT;
    const POW5_BITCOUNT = FLOAT128_POW5_BITCOUNT;

    const bound1 = 55;
    const bound2 = 127;
    const adjust_q = true;

    fn computePow5(i: u32) [4]u64 {
        const base = i / FLOAT128_POW5_TABLE_SIZE;
        const base2 = base * FLOAT128_POW5_TABLE_SIZE;
        const mul = &FLOAT128_POW5_SPLIT[base];
        if (i == base2) {
            return mul.*;
        } else {
            const offset = i - base2;
            const m = &FLOAT128_POW5_TABLE[offset];
            const delta = pow5Bits(i) - pow5Bits(base2);

            const shift: u6 = @intCast(2 * (i % 32));
            const corr: u32 = @intCast((FLOAT128_POW5_ERRORS[i / 32] >> shift) & 3);
            return mul_128_256_shift(m, mul, delta, corr);
        }
    }

    fn computeInvPow5(i: u32) [4]u64 {
        const base = (i + FLOAT128_POW5_TABLE_SIZE - 1) / FLOAT128_POW5_TABLE_SIZE;
        const base2 = base * FLOAT128_POW5_TABLE_SIZE;
        const mul = &FLOAT128_POW5_INV_SPLIT[base]; // 1 / 5^base2
        if (i == base2) {
            return .{ mul[0] + 1, mul[1], mul[2], mul[3] };
        } else {
            const offset = base2 - i;
            const m = &FLOAT128_POW5_TABLE[offset]; // 5^offset
            const delta = pow5Bits(base2) - pow5Bits(i);

            const shift: u6 = @intCast(2 * (i % 32));
            const corr: u32 = @intCast(((FLOAT128_POW5_INV_ERRORS[i / 32] >> shift) & 3) + 1);
            return mul_128_256_shift(m, mul, delta, corr);
        }
    }
};

fn mulShift64(m: u64, mul: *const [2]u64, j: u32) u64 {
    std.debug.assert(j > 64);
    const b0 = @as(u128, m) * mul[0];
    const b2 = @as(u128, m) * mul[1];

    if (j < 128) {
        const shift: u6 = @intCast(j - 64);
        return @intCast(((b0 >> 64) + b2) >> shift);
    } else {
        return 0;
    }
}

pub const Backend64_TablesFull = struct {
    const T = u64;
    const mulShift = mulShift64;
    const POW5_INV_BITCOUNT = FLOAT64_POW5_INV_BITCOUNT;
    const POW5_BITCOUNT = FLOAT64_POW5_BITCOUNT;

    const bound1 = 21;
    const bound2 = 63;
    const adjust_q = false;

    fn computePow5(i: u32) [2]u64 {
        return FLOAT64_POW5_SPLIT[i];
    }

    fn computeInvPow5(i: u32) [2]u64 {
        return FLOAT64_POW5_INV_SPLIT[i];
    }
};

pub const Backend64_TablesSmall = struct {
    const T = u64;
    const mulShift = mulShift64;
    const POW5_INV_BITCOUNT = FLOAT64_POW5_INV_BITCOUNT;
    const POW5_BITCOUNT = FLOAT64_POW5_BITCOUNT;

    const bound1 = 21;
    const bound2 = 63;
    const adjust_q = false;

    fn computePow5(i: u32) [2]u64 {
        const base = i / FLOAT64_POW5_TABLE_SIZE;
        const base2 = base * FLOAT64_POW5_TABLE_SIZE;
        const mul = &FLOAT64_POW5_SPLIT2[base];
        if (i == base2) {
            return .{ mul[0], mul[1] };
        } else {
            const offset = i - base2;
            const m = FLOAT64_POW5_TABLE[offset];
            const b0 = @as(u128, m) * mul[0];
            const b2 = @as(u128, m) * mul[1];
            const delta: u7 = @intCast(pow5Bits(i) - pow5Bits(base2));
            const shift: u5 = @intCast((i % 16) << 1);
            const shifted_sum = ((b0 >> delta) + (b2 << (64 - delta))) + 1 + ((FLOAT64_POW5_OFFSETS[i / 16] >> shift) & 3);
            return .{ @truncate(shifted_sum), @truncate(shifted_sum >> 64) };
        }
    }

    fn computeInvPow5(i: u32) [2]u64 {
        const base = (i + FLOAT64_POW5_TABLE_SIZE - 1) / FLOAT64_POW5_TABLE_SIZE;
        const base2 = base * FLOAT64_POW5_TABLE_SIZE;
        const mul = &FLOAT64_POW5_INV_SPLIT2[base]; // 1 / 5^base2
        if (i == base2) {
            return .{ mul[0], mul[1] };
        } else {
            const offset = base2 - i;
            const m = FLOAT64_POW5_TABLE[offset]; // 5^offset
            const b0 = @as(u128, m) * (mul[0] - 1);
            const b2 = @as(u128, m) * mul[1]; // 1/5^base2 * 5^offset = 1/5^(base2-offset) = 1/5^i
            const delta: u7 = @intCast(pow5Bits(base2) - pow5Bits(i));
            const shift: u5 = @intCast((i % 16) << 1);
            const shifted_sum = ((b0 >> delta) + (b2 << (64 - delta))) + 1 + ((FLOAT64_POW5_INV_OFFSETS[i / 16] >> shift) & 3);
            return .{ @truncate(shifted_sum), @truncate(shifted_sum >> 64) };
        }
    }
};

const FLOAT64_POW5_INV_BITCOUNT = 125;
const FLOAT64_POW5_BITCOUNT = 125;

// zig fmt: off
//
// f64 small tables: 816 bytes

const FLOAT64_POW5_TABLE_SIZE: comptime_int = FLOAT64_POW5_TABLE.len;

const FLOAT64_POW5_TABLE: [26]u64 = .{
                    1,                  5,
                   25,                125,
                  625,               3125,
                15625,              78125,
               390625,            1953125,
              9765625,           48828125,
            244140625,         1220703125,
           6103515625,        30517578125,
         152587890625,       762939453125,
        3814697265625,     19073486328125,
       95367431640625,    476837158203125,
     2384185791015625,  11920928955078125,
    59604644775390625, 298023223876953125,
};

const FLOAT64_POW5_SPLIT2: [13][2]u64 = .{
  .{                    0, 1152921504606846976 },
  .{                    0, 1490116119384765625 },
  .{  1032610780636961552, 1925929944387235853 },
  .{  7910200175544436838, 1244603055572228341 },
  .{ 16941905809032713930, 1608611746708759036 },
  .{ 13024893955298202172, 2079081953128979843 },
  .{  6607496772837067824, 1343575221513417750 },
  .{ 17332926989895652603, 1736530273035216783 },
  .{ 13037379183483547984, 2244412773384604712 },
  .{  1605989338741628675, 1450417759929778918 },
  .{  9630225068416591280, 1874621017369538693 },
  .{   665883850346957067, 1211445438634777304 },
  .{ 14931890668723713708, 1565756531257009982 }
};

const FLOAT64_POW5_OFFSETS: [21]u32 = .{
    0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x40000000, 0x59695995, 0x55545555, 0x56555515,
    0x41150504, 0x40555410, 0x44555145, 0x44504540,
    0x45555550, 0x40004000, 0x96440440, 0x55565565,
    0x54454045, 0x40154151, 0x55559155, 0x51405555,
    0x00000105,
};

const FLOAT64_POW5_INV_SPLIT2: [15][2]u64 = .{
  .{                    1, 2305843009213693952 },
  .{  5955668970331000884, 1784059615882449851 },
  .{  8982663654677661702, 1380349269358112757 },
  .{  7286864317269821294, 2135987035920910082 },
  .{  7005857020398200553, 1652639921975621497 },
  .{ 17965325103354776697, 1278668206209430417 },
  .{  8928596168509315048, 1978643211784836272 },
  .{ 10075671573058298858, 1530901034580419511 },
  .{   597001226353042382, 1184477304306571148 },
  .{  1527430471115325346, 1832889850782397517 },
  .{ 12533209867169019542, 1418129833677084982 },
  .{  5577825024675947042, 2194449627517475473 },
  .{ 11006974540203867551, 1697873161311732311 },
  .{ 10313493231639821582, 1313665730009899186 },
  .{ 12701016819766672773, 2032799256770390445 }
};

const FLOAT64_POW5_INV_OFFSETS: [19]u32 = .{
    0x54544554, 0x04055545, 0x10041000, 0x00400414,
    0x40010000, 0x41155555, 0x00000454, 0x00010044,
    0x40000000, 0x44000041, 0x50454450, 0x55550054,
    0x51655554, 0x40004000, 0x01000001, 0x00010500,
    0x51515411, 0x05555554, 0x00000000,
};


// zig fmt: off

// f64 full tables: 10688 bytes

const FLOAT64_POW5_SPLIT: [326][2]u64 = .{
  .{                    0, 1152921504606846976 }, .{                    0, 1441151880758558720 },
  .{                    0, 1801439850948198400 }, .{                    0, 2251799813685248000 },
  .{                    0, 1407374883553280000 }, .{                    0, 1759218604441600000 },
  .{                    0, 2199023255552000000 }, .{                    0, 1374389534720000000 },
  .{                    0, 1717986918400000000 }, .{                    0, 2147483648000000000 },
  .{                    0, 1342177280000000000 }, .{                    0, 1677721600000000000 },
  .{                    0, 2097152000000000000 }, .{                    0, 1310720000000000000 },
  .{                    0, 1638400000000000000 }, .{                    0, 2048000000000000000 },
  .{                    0, 1280000000000000000 }, .{                    0, 1600000000000000000 },
  .{                    0, 2000000000000000000 }, .{                    0, 1250000000000000000 },
  .{                    0, 1562500000000000000 }, .{                    0, 1953125000000000000 },
  .{                    0, 1220703125000000000 }, .{                    0, 1525878906250000000 },
  .{                    0, 1907348632812500000 }, .{                    0, 1192092895507812500 },
  .{                    0, 1490116119384765625 }, .{  4611686018427387904, 1862645149230957031 },
  .{  9799832789158199296, 1164153218269348144 }, .{ 12249790986447749120, 1455191522836685180 },
  .{ 15312238733059686400, 1818989403545856475 }, .{ 14528612397897220096, 2273736754432320594 },
  .{ 13692068767113150464, 1421085471520200371 }, .{ 12503399940464050176, 1776356839400250464 },
  .{ 15629249925580062720, 2220446049250313080 }, .{  9768281203487539200, 1387778780781445675 },
  .{  7598665485932036096, 1734723475976807094 }, .{   274959820560269312, 2168404344971008868 },
  .{  9395221924704944128, 1355252715606880542 }, .{  2520655369026404352, 1694065894508600678 },
  .{ 12374191248137781248, 2117582368135750847 }, .{ 14651398557727195136, 1323488980084844279 },
  .{ 13702562178731606016, 1654361225106055349 }, .{  3293144668132343808, 2067951531382569187 },
  .{ 18199116482078572544, 1292469707114105741 }, .{  8913837547316051968, 1615587133892632177 },
  .{ 15753982952572452864, 2019483917365790221 }, .{ 12152082354571476992, 1262177448353618888 },
  .{ 15190102943214346240, 1577721810442023610 }, .{  9764256642163156992, 1972152263052529513 },
  .{ 17631875447420442880, 1232595164407830945 }, .{  8204786253993389888, 1540743955509788682 },
  .{  1032610780636961552, 1925929944387235853 }, .{  2951224747111794922, 1203706215242022408 },
  .{  3689030933889743652, 1504632769052528010 }, .{ 13834660704216955373, 1880790961315660012 },
  .{ 17870034976990372916, 1175494350822287507 }, .{ 17725857702810578241, 1469367938527859384 },
  .{  3710578054803671186, 1836709923159824231 }, .{    26536550077201078, 2295887403949780289 },
  .{ 11545800389866720434, 1434929627468612680 }, .{ 14432250487333400542, 1793662034335765850 },
  .{  8816941072311974870, 2242077542919707313 }, .{ 17039803216263454053, 1401298464324817070 },
  .{ 12076381983474541759, 1751623080406021338 }, .{  5872105442488401391, 2189528850507526673 },
  .{ 15199280947623720629, 1368455531567204170 }, .{  9775729147674874978, 1710569414459005213 },
  .{ 16831347453020981627, 2138211768073756516 }, .{  1296220121283337709, 1336382355046097823 },
  .{ 15455333206886335848, 1670477943807622278 }, .{ 10095794471753144002, 2088097429759527848 },
  .{  6309871544845715001, 1305060893599704905 }, .{ 12499025449484531656, 1631326116999631131 },
  .{ 11012095793428276666, 2039157646249538914 }, .{ 11494245889320060820, 1274473528905961821 },
  .{   532749306367912313, 1593091911132452277 }, .{  5277622651387278295, 1991364888915565346 },
  .{  7910200175544436838, 1244603055572228341 }, .{ 14499436237857933952, 1555753819465285426 },
  .{  8900923260467641632, 1944692274331606783 }, .{ 12480606065433357876, 1215432671457254239 },
  .{ 10989071563364309441, 1519290839321567799 }, .{  9124653435777998898, 1899113549151959749 },
  .{  8008751406574943263, 1186945968219974843 }, .{  5399253239791291175, 1483682460274968554 },
  .{ 15972438586593889776, 1854603075343710692 }, .{   759402079766405302, 1159126922089819183 },
  .{ 14784310654990170340, 1448908652612273978 }, .{  9257016281882937117, 1811135815765342473 },
  .{ 16182956370781059300, 2263919769706678091 }, .{  7808504722524468110, 1414949856066673807 },
  .{  5148944884728197234, 1768687320083342259 }, .{  1824495087482858639, 2210859150104177824 },
  .{  1140309429676786649, 1381786968815111140 }, .{  1425386787095983311, 1727233711018888925 },
  .{  6393419502297367043, 2159042138773611156 }, .{ 13219259225790630210, 1349401336733506972 },
  .{ 16524074032238287762, 1686751670916883715 }, .{ 16043406521870471799, 2108439588646104644 },
  .{   803757039314269066, 1317774742903815403 }, .{ 14839754354425000045, 1647218428629769253 },
  .{  4714634887749086344, 2059023035787211567 }, .{  9864175832484260821, 1286889397367007229 },
  .{ 16941905809032713930, 1608611746708759036 }, .{  2730638187581340797, 2010764683385948796 },
  .{ 10930020904093113806, 1256727927116217997 }, .{ 18274212148543780162, 1570909908895272496 },
  .{  4396021111970173586, 1963637386119090621 }, .{  5053356204195052443, 1227273366324431638 },
  .{ 15540067292098591362, 1534091707905539547 }, .{ 14813398096695851299, 1917614634881924434 },
  .{ 13870059828862294966, 1198509146801202771 }, .{ 12725888767650480803, 1498136433501503464 },
  .{ 15907360959563101004, 1872670541876879330 }, .{ 14553786618154326031, 1170419088673049581 },
  .{  4357175217410743827, 1463023860841311977 }, .{ 10058155040190817688, 1828779826051639971 },
  .{  7961007781811134206, 2285974782564549964 }, .{ 14199001900486734687, 1428734239102843727 },
  .{ 13137066357181030455, 1785917798878554659 }, .{ 11809646928048900164, 2232397248598193324 },
  .{ 16604401366885338411, 1395248280373870827 }, .{ 16143815690179285109, 1744060350467338534 },
  .{ 10956397575869330579, 2180075438084173168 }, .{  6847748484918331612, 1362547148802608230 },
  .{ 17783057643002690323, 1703183936003260287 }, .{ 17617136035325974999, 2128979920004075359 },
  .{ 17928239049719816230, 1330612450002547099 }, .{ 17798612793722382384, 1663265562503183874 },
  .{ 13024893955298202172, 2079081953128979843 }, .{  5834715712847682405, 1299426220705612402 },
  .{ 16516766677914378815, 1624282775882015502 }, .{ 11422586310538197711, 2030353469852519378 },
  .{ 11750802462513761473, 1268970918657824611 }, .{ 10076817059714813937, 1586213648322280764 },
  .{ 12596021324643517422, 1982767060402850955 }, .{  5566670318688504437, 1239229412751781847 },
  .{  2346651879933242642, 1549036765939727309 }, .{  7545000868343941206, 1936295957424659136 },
  .{  4715625542714963254, 1210184973390411960 }, .{  5894531928393704067, 1512731216738014950 },
  .{ 16591536947346905892, 1890914020922518687 }, .{ 17287239619732898039, 1181821263076574179 },
  .{ 16997363506238734644, 1477276578845717724 }, .{  2799960309088866689, 1846595723557147156 },
  .{ 10973347230035317489, 1154122327223216972 }, .{ 13716684037544146861, 1442652909029021215 },
  .{ 12534169028502795672, 1803316136286276519 }, .{ 11056025267201106687, 2254145170357845649 },
  .{ 18439230838069161439, 1408840731473653530 }, .{ 13825666510731675991, 1761050914342066913 },
  .{  3447025083132431277, 2201313642927583642 }, .{  6766076695385157452, 1375821026829739776 },
  .{  8457595869231446815, 1719776283537174720 }, .{ 10571994836539308519, 2149720354421468400 },
  .{  6607496772837067824, 1343575221513417750 }, .{ 17482743002901110588, 1679469026891772187 },
  .{ 17241742735199000331, 2099336283614715234 }, .{ 15387775227926763111, 1312085177259197021 },
  .{  5399660979626290177, 1640106471573996277 }, .{ 11361262242960250625, 2050133089467495346 },
  .{ 11712474920277544544, 1281333180917184591 }, .{ 10028907631919542777, 1601666476146480739 },
  .{  7924448521472040567, 2002083095183100924 }, .{ 14176152362774801162, 1251301934489438077 },
  .{  3885132398186337741, 1564127418111797597 }, .{  9468101516160310080, 1955159272639746996 },
  .{ 15140935484454969608, 1221974545399841872 }, .{   479425281859160394, 1527468181749802341 },
  .{  5210967620751338397, 1909335227187252926 }, .{ 17091912818251750210, 1193334516992033078 },
  .{ 12141518985959911954, 1491668146240041348 }, .{ 15176898732449889943, 1864585182800051685 },
  .{ 11791404716994875166, 1165365739250032303 }, .{ 10127569877816206054, 1456707174062540379 },
  .{  8047776328842869663, 1820883967578175474 }, .{   836348374198811271, 2276104959472719343 },
  .{  7440246761515338900, 1422565599670449589 }, .{ 13911994470321561530, 1778206999588061986 },
  .{  8166621051047176104, 2222758749485077483 }, .{  2798295147690791113, 1389224218428173427 },
  .{ 17332926989895652603, 1736530273035216783 }, .{ 17054472718942177850, 2170662841294020979 },
  .{  8353202440125167204, 1356664275808763112 }, .{ 10441503050156459005, 1695830344760953890 },
  .{  3828506775840797949, 2119787930951192363 }, .{    86973725686804766, 1324867456844495227 },
  .{ 13943775212390669669, 1656084321055619033 }, .{  3594660960206173375, 2070105401319523792 },
  .{  2246663100128858359, 1293815875824702370 }, .{ 12031700912015848757, 1617269844780877962 },
  .{  5816254103165035138, 2021587305976097453 }, .{  5941001823691840913, 1263492066235060908 },
  .{  7426252279614801142, 1579365082793826135 }, .{  4671129331091113523, 1974206353492282669 },
  .{  5225298841145639904, 1233878970932676668 }, .{  6531623551432049880, 1542348713665845835 },
  .{  3552843420862674446, 1927935892082307294 }, .{ 16055585193321335241, 1204959932551442058 },
  .{ 10846109454796893243, 1506199915689302573 }, .{ 18169322836923504458, 1882749894611628216 },
  .{ 11355826773077190286, 1176718684132267635 }, .{  9583097447919099954, 1470898355165334544 },
  .{ 11978871809898874942, 1838622943956668180 }, .{ 14973589762373593678, 2298278679945835225 },
  .{  2440964573842414192, 1436424174966147016 }, .{  3051205717303017741, 1795530218707683770 },
  .{ 13037379183483547984, 2244412773384604712 }, .{  8148361989677217490, 1402757983365377945 },
  .{ 14797138505523909766, 1753447479206722431 }, .{ 13884737113477499304, 2191809349008403039 },
  .{ 15595489723564518921, 1369880843130251899 }, .{ 14882676136028260747, 1712351053912814874 },
  .{  9379973133180550126, 2140438817391018593 }, .{ 17391698254306313589, 1337774260869386620 },
  .{  3292878744173340370, 1672217826086733276 }, .{  4116098430216675462, 2090272282608416595 },
  .{   266718509671728212, 1306420176630260372 }, .{   333398137089660265, 1633025220787825465 },
  .{  5028433689789463235, 2041281525984781831 }, .{ 10060300083759496378, 1275800953740488644 },
  .{ 12575375104699370472, 1594751192175610805 }, .{  1884160825592049379, 1993438990219513507 },
  .{ 17318501580490888525, 1245899368887195941 }, .{  7813068920331446945, 1557374211108994927 },
  .{  5154650131986920777, 1946717763886243659 }, .{   915813323278131534, 1216698602428902287 },
  .{ 14979824709379828129, 1520873253036127858 }, .{  9501408849870009354, 1901091566295159823 },
  .{ 12855909558809837702, 1188182228934474889 }, .{  2234828893230133415, 1485227786168093612 },
  .{  2793536116537666769, 1856534732710117015 }, .{  8663489100477123587, 1160334207943823134 },
  .{  1605989338741628675, 1450417759929778918 }, .{ 11230858710281811652, 1813022199912223647 },
  .{  9426887369424876662, 2266277749890279559 }, .{ 12809333633531629769, 1416423593681424724 },
  .{ 16011667041914537212, 1770529492101780905 }, .{  6179525747111007803, 2213161865127226132 },
  .{ 13085575628799155685, 1383226165704516332 }, .{ 16356969535998944606, 1729032707130645415 },
  .{ 15834525901571292854, 2161290883913306769 }, .{  2979049660840976177, 1350806802445816731 },
  .{ 17558870131333383934, 1688508503057270913 }, .{  8113529608884566205, 2110635628821588642 },
  .{  9682642023980241782, 1319147268013492901 }, .{ 16714988548402690132, 1648934085016866126 },
  .{ 11670363648648586857, 2061167606271082658 }, .{ 11905663298832754689, 1288229753919426661 },
  .{  1047021068258779650, 1610287192399283327 }, .{ 15143834390605638274, 2012858990499104158 },
  .{  4853210475701136017, 1258036869061940099 }, .{  1454827076199032118, 1572546086327425124 },
  .{  1818533845248790147, 1965682607909281405 }, .{  3442426662494187794, 1228551629943300878 },
  .{ 13526405364972510550, 1535689537429126097 }, .{  3072948650933474476, 1919611921786407622 },
  .{ 15755650962115585259, 1199757451116504763 }, .{ 15082877684217093670, 1499696813895630954 },
  .{  9630225068416591280, 1874621017369538693 }, .{  8324733676974063502, 1171638135855961683 },
  .{  5794231077790191473, 1464547669819952104 }, .{  7242788847237739342, 1830684587274940130 },
  .{ 18276858095901949986, 2288355734093675162 }, .{ 16034722328366106645, 1430222333808546976 },
  .{  1596658836748081690, 1787777917260683721 }, .{  6607509564362490017, 2234722396575854651 },
  .{  1823850468512862308, 1396701497859909157 }, .{  6891499104068465790, 1745876872324886446 },
  .{ 17837745916940358045, 2182346090406108057 }, .{  4231062170446641922, 1363966306503817536 },
  .{  5288827713058302403, 1704957883129771920 }, .{  6611034641322878003, 2131197353912214900 },
  .{ 13355268687681574560, 1331998346195134312 }, .{ 16694085859601968200, 1664997932743917890 },
  .{ 11644235287647684442, 2081247415929897363 }, .{  4971804045566108824, 1300779634956185852 },
  .{  6214755056957636030, 1625974543695232315 }, .{  3156757802769657134, 2032468179619040394 },
  .{  6584659645158423613, 1270292612261900246 }, .{ 17454196593302805324, 1587865765327375307 },
  .{ 17206059723201118751, 1984832206659219134 }, .{  6142101308573311315, 1240520129162011959 },
  .{  3065940617289251240, 1550650161452514949 }, .{  8444111790038951954, 1938312701815643686 },
  .{   665883850346957067, 1211445438634777304 }, .{   832354812933696334, 1514306798293471630 },
  .{ 10263815553021896226, 1892883497866839537 }, .{ 17944099766707154901, 1183052186166774710 },
  .{ 13206752671529167818, 1478815232708468388 }, .{ 16508440839411459773, 1848519040885585485 },
  .{ 12623618533845856310, 1155324400553490928 }, .{ 15779523167307320387, 1444155500691863660 },
  .{  1277659885424598868, 1805194375864829576 }, .{  1597074856780748586, 2256492969831036970 },
  .{  5609857803915355770, 1410308106144398106 }, .{ 16235694291748970521, 1762885132680497632 },
  .{  1847873790976661535, 2203606415850622041 }, .{ 12684136165428883219, 1377254009906638775 },
  .{ 11243484188358716120, 1721567512383298469 }, .{   219297180166231438, 2151959390479123087 },
  .{  7054589765244976505, 1344974619049451929 }, .{ 13429923224983608535, 1681218273811814911 },
  .{ 12175718012802122765, 2101522842264768639 }, .{ 14527352785642408584, 1313451776415480399 },
  .{ 13547504963625622826, 1641814720519350499 }, .{ 12322695186104640628, 2052268400649188124 },
  .{ 16925056528170176201, 1282667750405742577 }, .{  7321262604930556539, 1603334688007178222 },
  .{ 18374950293017971482, 2004168360008972777 }, .{  4566814905495150320, 1252605225005607986 },
  .{ 14931890668723713708, 1565756531257009982 }, .{  9441491299049866327, 1957195664071262478 },
  .{  1289246043478778550, 1223247290044539049 }, .{  6223243572775861092, 1529059112555673811 },
  .{  3167368447542438461, 1911323890694592264 }, .{  1979605279714024038, 1194577431684120165 },
  .{  7086192618069917952, 1493221789605150206 }, .{ 18081112809442173248, 1866527237006437757 },
  .{ 13606538515115052232, 1166579523129023598 }, .{  7784801107039039482, 1458224403911279498 },
  .{   507629346944023544, 1822780504889099373 }, .{  5246222702107417334, 2278475631111374216 },
  .{  3278889188817135834, 1424047269444608885 }, .{  8710297504448807696, 1780059086805761106 }
};

const FLOAT64_POW5_INV_SPLIT: [342][2]u64 = .{
  .{                    1, 2305843009213693952 }, .{ 11068046444225730970, 1844674407370955161 },
  .{  5165088340638674453, 1475739525896764129 }, .{  7821419487252849886, 1180591620717411303 },
  .{  8824922364862649494, 1888946593147858085 }, .{  7059937891890119595, 1511157274518286468 },
  .{ 13026647942995916322, 1208925819614629174 }, .{  9774590264567735146, 1934281311383406679 },
  .{ 11509021026396098440, 1547425049106725343 }, .{ 16585914450600699399, 1237940039285380274 },
  .{ 15469416676735388068, 1980704062856608439 }, .{ 16064882156130220778, 1584563250285286751 },
  .{  9162556910162266299, 1267650600228229401 }, .{  7281393426775805432, 2028240960365167042 },
  .{ 16893161185646375315, 1622592768292133633 }, .{  2446482504291369283, 1298074214633706907 },
  .{  7603720821608101175, 2076918743413931051 }, .{  2393627842544570617, 1661534994731144841 },
  .{ 16672297533003297786, 1329227995784915872 }, .{ 11918280793837635165, 2126764793255865396 },
  .{  5845275820328197809, 1701411834604692317 }, .{ 15744267100488289217, 1361129467683753853 },
  .{  3054734472329800808, 2177807148294006166 }, .{ 17201182836831481939, 1742245718635204932 },
  .{  6382248639981364905, 1393796574908163946 }, .{  2832900194486363201, 2230074519853062314 },
  .{  5955668970331000884, 1784059615882449851 }, .{  1075186361522890384, 1427247692705959881 },
  .{ 12788344622662355584, 2283596308329535809 }, .{ 13920024512871794791, 1826877046663628647 },
  .{  3757321980813615186, 1461501637330902918 }, .{ 10384555214134712795, 1169201309864722334 },
  .{  5547241898389809503, 1870722095783555735 }, .{  4437793518711847602, 1496577676626844588 },
  .{ 10928932444453298728, 1197262141301475670 }, .{ 17486291911125277965, 1915619426082361072 },
  .{  6610335899416401726, 1532495540865888858 }, .{ 12666966349016942027, 1225996432692711086 },
  .{ 12888448528943286597, 1961594292308337738 }, .{ 17689456452638449924, 1569275433846670190 },
  .{ 14151565162110759939, 1255420347077336152 }, .{  7885109000409574610, 2008672555323737844 },
  .{  9997436015069570011, 1606938044258990275 }, .{  7997948812055656009, 1285550435407192220 },
  .{ 12796718099289049614, 2056880696651507552 }, .{  2858676849947419045, 1645504557321206042 },
  .{ 13354987924183666206, 1316403645856964833 }, .{ 17678631863951955605, 2106245833371143733 },
  .{  3074859046935833515, 1684996666696914987 }, .{ 13527933681774397782, 1347997333357531989 },
  .{ 10576647446613305481, 2156795733372051183 }, .{ 15840015586774465031, 1725436586697640946 },
  .{  8982663654677661702, 1380349269358112757 }, .{ 18061610662226169046, 2208558830972980411 },
  .{ 10759939715039024913, 1766847064778384329 }, .{ 12297300586773130254, 1413477651822707463 },
  .{ 15986332124095098083, 2261564242916331941 }, .{  9099716884534168143, 1809251394333065553 },
  .{ 14658471137111155161, 1447401115466452442 }, .{  4348079280205103483, 1157920892373161954 },
  .{ 14335624477811986218, 1852673427797059126 }, .{  7779150767507678651, 1482138742237647301 },
  .{  2533971799264232598, 1185710993790117841 }, .{ 15122401323048503126, 1897137590064188545 },
  .{ 12097921058438802501, 1517710072051350836 }, .{  5988988032009131678, 1214168057641080669 },
  .{ 16961078480698431330, 1942668892225729070 }, .{ 13568862784558745064, 1554135113780583256 },
  .{  7165741412905085728, 1243308091024466605 }, .{ 11465186260648137165, 1989292945639146568 },
  .{ 16550846638002330379, 1591434356511317254 }, .{ 16930026125143774626, 1273147485209053803 },
  .{  4951948911778577463, 2037035976334486086 }, .{   272210314680951647, 1629628781067588869 },
  .{  3907117066486671641, 1303703024854071095 }, .{  6251387306378674625, 2085924839766513752 },
  .{ 16069156289328670670, 1668739871813211001 }, .{  9165976216721026213, 1334991897450568801 },
  .{  7286864317269821294, 2135987035920910082 }, .{ 16897537898041588005, 1708789628736728065 },
  .{ 13518030318433270404, 1367031702989382452 }, .{  6871453250525591353, 2187250724783011924 },
  .{  9186511415162383406, 1749800579826409539 }, .{ 11038557946871817048, 1399840463861127631 },
  .{ 10282995085511086630, 2239744742177804210 }, .{  8226396068408869304, 1791795793742243368 },
  .{ 13959814484210916090, 1433436634993794694 }, .{ 11267656730511734774, 2293498615990071511 },
  .{  5324776569667477496, 1834798892792057209 }, .{  7949170070475892320, 1467839114233645767 },
  .{ 17427382500606444826, 1174271291386916613 }, .{  5747719112518849781, 1878834066219066582 },
  .{ 15666221734240810795, 1503067252975253265 }, .{ 12532977387392648636, 1202453802380202612 },
  .{  5295368560860596524, 1923926083808324180 }, .{  4236294848688477220, 1539140867046659344 },
  .{  7078384693692692099, 1231312693637327475 }, .{ 11325415509908307358, 1970100309819723960 },
  .{  9060332407926645887, 1576080247855779168 }, .{ 14626963555825137356, 1260864198284623334 },
  .{ 12335095245094488799, 2017382717255397335 }, .{  9868076196075591040, 1613906173804317868 },
  .{ 15273158586344293478, 1291124939043454294 }, .{ 13369007293925138595, 2065799902469526871 },
  .{  7005857020398200553, 1652639921975621497 }, .{ 16672732060544291412, 1322111937580497197 },
  .{ 11918976037903224966, 2115379100128795516 }, .{  5845832015580669650, 1692303280103036413 },
  .{ 12055363241948356366, 1353842624082429130 }, .{   841837113407818570, 2166148198531886609 },
  .{  4362818505468165179, 1732918558825509287 }, .{ 14558301248600263113, 1386334847060407429 },
  .{ 12225235553534690011, 2218135755296651887 }, .{  2401490813343931363, 1774508604237321510 },
  .{  1921192650675145090, 1419606883389857208 }, .{ 17831303500047873437, 2271371013423771532 },
  .{  6886345170554478103, 1817096810739017226 }, .{  1819727321701672159, 1453677448591213781 },
  .{ 16213177116328979020, 1162941958872971024 }, .{ 14873036941900635463, 1860707134196753639 },
  .{ 15587778368262418694, 1488565707357402911 }, .{  8780873879868024632, 1190852565885922329 },
  .{  2981351763563108441, 1905364105417475727 }, .{ 13453127855076217722, 1524291284333980581 },
  .{  7073153469319063855, 1219433027467184465 }, .{ 11317045550910502167, 1951092843947495144 },
  .{ 12742985255470312057, 1560874275157996115 }, .{ 10194388204376249646, 1248699420126396892 },
  .{  1553625868034358140, 1997919072202235028 }, .{  8621598323911307159, 1598335257761788022 },
  .{ 17965325103354776697, 1278668206209430417 }, .{ 13987124906400001422, 2045869129935088668 },
  .{   121653480894270168, 1636695303948070935 }, .{    97322784715416134, 1309356243158456748 },
  .{ 14913111714512307107, 2094969989053530796 }, .{  8241140556867935363, 1675975991242824637 },
  .{ 17660958889720079260, 1340780792994259709 }, .{ 17189487779326395846, 2145249268790815535 },
  .{ 13751590223461116677, 1716199415032652428 }, .{ 18379969808252713988, 1372959532026121942 },
  .{ 14650556434236701088, 2196735251241795108 }, .{   652398703163629901, 1757388200993436087 },
  .{ 11589965406756634890, 1405910560794748869 }, .{  7475898206584884855, 2249456897271598191 },
  .{  2291369750525997561, 1799565517817278553 }, .{  9211793429904618695, 1439652414253822842 },
  .{ 18428218302589300235, 2303443862806116547 }, .{  7363877012587619542, 1842755090244893238 },
  .{ 13269799239553916280, 1474204072195914590 }, .{ 10615839391643133024, 1179363257756731672 },
  .{  2227947767661371545, 1886981212410770676 }, .{ 16539753473096738529, 1509584969928616540 },
  .{ 13231802778477390823, 1207667975942893232 }, .{  6413489186596184024, 1932268761508629172 },
  .{ 16198837793502678189, 1545815009206903337 }, .{  5580372605318321905, 1236652007365522670 },
  .{  8928596168509315048, 1978643211784836272 }, .{ 18210923379033183008, 1582914569427869017 },
  .{  7190041073742725760, 1266331655542295214 }, .{   436019273762630246, 2026130648867672343 },
  .{  7727513048493924843, 1620904519094137874 }, .{  9871359253537050198, 1296723615275310299 },
  .{  4726128361433549347, 2074757784440496479 }, .{  7470251503888749801, 1659806227552397183 },
  .{ 13354898832594820487, 1327844982041917746 }, .{ 13989140502667892133, 2124551971267068394 },
  .{ 14880661216876224029, 1699641577013654715 }, .{ 11904528973500979224, 1359713261610923772 },
  .{  4289851098633925465, 2175541218577478036 }, .{ 18189276137874781665, 1740432974861982428 },
  .{  3483374466074094362, 1392346379889585943 }, .{  1884050330976640656, 2227754207823337509 },
  .{  5196589079523222848, 1782203366258670007 }, .{ 15225317707844309248, 1425762693006936005 },
  .{  5913764258841343181, 2281220308811097609 }, .{  8420360221814984868, 1824976247048878087 },
  .{ 17804334621677718864, 1459980997639102469 }, .{ 17932816512084085415, 1167984798111281975 },
  .{ 10245762345624985047, 1868775676978051161 }, .{  4507261061758077715, 1495020541582440929 },
  .{  7295157664148372495, 1196016433265952743 }, .{  7982903447895485668, 1913626293225524389 },
  .{ 10075671573058298858, 1530901034580419511 }, .{  4371188443704728763, 1224720827664335609 },
  .{ 14372599139411386667, 1959553324262936974 }, .{ 15187428126271019657, 1567642659410349579 },
  .{ 15839291315758726049, 1254114127528279663 }, .{  3206773216762499739, 2006582604045247462 },
  .{ 13633465017635730761, 1605266083236197969 }, .{ 14596120828850494932, 1284212866588958375 },
  .{  4907049252451240275, 2054740586542333401 }, .{   236290587219081897, 1643792469233866721 },
  .{ 14946427728742906810, 1315033975387093376 }, .{ 16535586736504830250, 2104054360619349402 },
  .{  5849771759720043554, 1683243488495479522 }, .{ 15747863852001765813, 1346594790796383617 },
  .{ 10439186904235184007, 2154551665274213788 }, .{ 15730047152871967852, 1723641332219371030 },
  .{ 12584037722297574282, 1378913065775496824 }, .{  9066413911450387881, 2206260905240794919 },
  .{ 10942479943902220628, 1765008724192635935 }, .{  8753983955121776503, 1412006979354108748 },
  .{ 10317025513452932081, 2259211166966573997 }, .{   874922781278525018, 1807368933573259198 },
  .{  8078635854506640661, 1445895146858607358 }, .{ 13841606313089133175, 1156716117486885886 },
  .{ 14767872471458792434, 1850745787979017418 }, .{   746251532941302978, 1480596630383213935 },
  .{   597001226353042382, 1184477304306571148 }, .{ 15712597221132509104, 1895163686890513836 },
  .{  8880728962164096960, 1516130949512411069 }, .{ 10793931984473187891, 1212904759609928855 },
  .{ 17270291175157100626, 1940647615375886168 }, .{  2748186495899949531, 1552518092300708935 },
  .{  2198549196719959625, 1242014473840567148 }, .{ 18275073973719576693, 1987223158144907436 },
  .{ 10930710364233751031, 1589778526515925949 }, .{ 12433917106128911148, 1271822821212740759 },
  .{  8826220925580526867, 2034916513940385215 }, .{  7060976740464421494, 1627933211152308172 },
  .{ 16716827836597268165, 1302346568921846537 }, .{ 11989529279587987770, 2083754510274954460 },
  .{  9591623423670390216, 1667003608219963568 }, .{ 15051996368420132820, 1333602886575970854 },
  .{ 13015147745246481542, 2133764618521553367 }, .{  3033420566713364587, 1707011694817242694 },
  .{  6116085268112601993, 1365609355853794155 }, .{  9785736428980163188, 2184974969366070648 },
  .{ 15207286772667951197, 1747979975492856518 }, .{  1097782973908629988, 1398383980394285215 },
  .{  1756452758253807981, 2237414368630856344 }, .{  5094511021344956708, 1789931494904685075 },
  .{  4075608817075965366, 1431945195923748060 }, .{  6520974107321544586, 2291112313477996896 },
  .{  1527430471115325346, 1832889850782397517 }, .{ 12289990821117991246, 1466311880625918013 },
  .{ 17210690286378213644, 1173049504500734410 }, .{  9090360384495590213, 1876879207201175057 },
  .{ 18340334751822203140, 1501503365760940045 }, .{ 14672267801457762512, 1201202692608752036 },
  .{ 16096930852848599373, 1921924308174003258 }, .{  1809498238053148529, 1537539446539202607 },
  .{ 12515645034668249793, 1230031557231362085 }, .{  1578287981759648052, 1968050491570179337 },
  .{ 12330676829633449412, 1574440393256143469 }, .{ 13553890278448669853, 1259552314604914775 },
  .{  3239480371808320148, 2015283703367863641 }, .{ 17348979556414297411, 1612226962694290912 },
  .{  6500486015647617283, 1289781570155432730 }, .{ 10400777625036187652, 2063650512248692368 },
  .{ 15699319729512770768, 1650920409798953894 }, .{ 16248804598352126938, 1320736327839163115 },
  .{  7551343283653851484, 2113178124542660985 }, .{  6041074626923081187, 1690542499634128788 },
  .{ 12211557331022285596, 1352433999707303030 }, .{  1091747655926105338, 2163894399531684849 },
  .{  4562746939482794594, 1731115519625347879 }, .{  7339546366328145998, 1384892415700278303 },
  .{  8053925371383123274, 2215827865120445285 }, .{  6443140297106498619, 1772662292096356228 },
  .{ 12533209867169019542, 1418129833677084982 }, .{  5295740528502789974, 2269007733883335972 },
  .{ 15304638867027962949, 1815206187106668777 }, .{  4865013464138549713, 1452164949685335022 },
  .{ 14960057215536570740, 1161731959748268017 }, .{  9178696285890871890, 1858771135597228828 },
  .{ 14721654658196518159, 1487016908477783062 }, .{  4398626097073393881, 1189613526782226450 },
  .{  7037801755317430209, 1903381642851562320 }, .{  5630241404253944167, 1522705314281249856 },
  .{   814844308661245011, 1218164251424999885 }, .{  1303750893857992017, 1949062802279999816 },
  .{ 15800395974054034906, 1559250241823999852 }, .{  5261619149759407279, 1247400193459199882 },
  .{ 12107939454356961969, 1995840309534719811 }, .{  5997002748743659252, 1596672247627775849 },
  .{  8486951013736837725, 1277337798102220679 }, .{  2511075177753209390, 2043740476963553087 },
  .{ 13076906586428298482, 1634992381570842469 }, .{ 14150874083884549109, 1307993905256673975 },
  .{  4194654460505726958, 2092790248410678361 }, .{ 18113118827372222859, 1674232198728542688 },
  .{  3422448617672047318, 1339385758982834151 }, .{ 16543964232501006678, 2143017214372534641 },
  .{  9545822571258895019, 1714413771498027713 }, .{ 15015355686490936662, 1371531017198422170 },
  .{  5577825024675947042, 2194449627517475473 }, .{ 11840957649224578280, 1755559702013980378 },
  .{ 16851463748863483271, 1404447761611184302 }, .{ 12204946739213931940, 2247116418577894884 },
  .{ 13453306206113055875, 1797693134862315907 }, .{  3383947335406624054, 1438154507889852726 },
  .{ 16482362180876329456, 2301047212623764361 }, .{  9496540929959153242, 1840837770099011489 },
  .{ 11286581558709232917, 1472670216079209191 }, .{  5339916432225476010, 1178136172863367353 },
  .{  4854517476818851293, 1885017876581387765 }, .{  3883613981455081034, 1508014301265110212 },
  .{ 14174937629389795797, 1206411441012088169 }, .{ 11611853762797942306, 1930258305619341071 },
  .{  5600134195496443521, 1544206644495472857 }, .{ 15548153800622885787, 1235365315596378285 },
  .{  6430302007287065643, 1976584504954205257 }, .{ 16212288050055383484, 1581267603963364205 },
  .{ 12969830440044306787, 1265014083170691364 }, .{  9683682259845159889, 2024022533073106183 },
  .{ 15125643437359948558, 1619218026458484946 }, .{  8411165935146048523, 1295374421166787957 },
  .{ 17147214310975587960, 2072599073866860731 }, .{ 10028422634038560045, 1658079259093488585 },
  .{  8022738107230848036, 1326463407274790868 }, .{  9147032156827446534, 2122341451639665389 },
  .{ 11006974540203867551, 1697873161311732311 }, .{  5116230817421183718, 1358298529049385849 },
  .{ 15564666937357714594, 2173277646479017358 }, .{  1383687105660440706, 1738622117183213887 },
  .{ 12174996128754083534, 1390897693746571109 }, .{  8411947361780802685, 2225436309994513775 },
  .{  6729557889424642148, 1780349047995611020 }, .{  5383646311539713719, 1424279238396488816 },
  .{  1235136468979721303, 2278846781434382106 }, .{ 15745504434151418335, 1823077425147505684 },
  .{ 16285752362063044992, 1458461940118004547 }, .{  5649904260166615347, 1166769552094403638 },
  .{  5350498001524674232, 1866831283351045821 }, .{   591049586477829062, 1493465026680836657 },
  .{ 11540886113407994219, 1194772021344669325 }, .{    18673707743239135, 1911635234151470921 },
  .{ 14772334225162232601, 1529308187321176736 }, .{  8128518565387875758, 1223446549856941389 },
  .{  1937583260394870242, 1957514479771106223 }, .{  8928764237799716840, 1566011583816884978 },
  .{ 14521709019723594119, 1252809267053507982 }, .{  8477339172590109297, 2004494827285612772 },
  .{ 17849917782297818407, 1603595861828490217 }, .{  6901236596354434079, 1282876689462792174 },
  .{ 18420676183650915173, 2052602703140467478 }, .{  3668494502695001169, 1642082162512373983 },
  .{ 10313493231639821582, 1313665730009899186 }, .{  9122891541139893884, 2101865168015838698 },
  .{ 14677010862395735754, 1681492134412670958 }, .{   673562245690857633, 1345193707530136767 }
};

// zig fmt: off
//
// f128 small tables: 9072 bytes

const FLOAT128_POW5_INV_BITCOUNT = 249;
const FLOAT128_POW5_BITCOUNT = 249;
const FLOAT128_POW5_TABLE_SIZE: comptime_int = FLOAT128_POW5_TABLE.len;

const FLOAT128_POW5_TABLE: [56][2]u64 = .{
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

const FLOAT128_POW5_SPLIT: [89][4]u64 = .{
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
const FLOAT128_POW5_ERRORS: [156]u64 = .{
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

const FLOAT128_POW5_INV_SPLIT: [89][4]u64 = .{
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

const FLOAT128_POW5_INV_ERRORS: [154]u64 = .{
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

const builtin = @import("builtin");

fn check(comptime T: type, value: T, comptime expected: []const u8) !void {
    const I = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @bitSizeOf(T) } });

    var buf: [6000]u8 = undefined;
    const value_bits: I = @bitCast(value);
    const s = try formatFloat(&buf, value, .{});
    try std.testing.expectEqualStrings(expected, s);

    if (T == f80 and builtin.target.os.tag == .windows and builtin.target.cpu.arch == .x86_64) return;

    const o = try std.fmt.parseFloat(T, s);
    const o_bits: I = @bitCast(o);

    if (std.math.isNan(value)) {
        try std.testing.expect(std.math.isNan(o));
    } else {
        try std.testing.expectEqual(value_bits, o_bits);
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

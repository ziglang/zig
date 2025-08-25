const std = @import("std");
const common = @import("common.zig");
const FloatStream = @import("FloatStream.zig");
const isEightDigits = common.isEightDigits;
const Number = common.Number;

/// Parse 8 digits, loaded as bytes in little-endian order.
///
/// This uses the trick where every digit is in [0x030, 0x39],
/// and therefore can be parsed in 3 multiplications, much
/// faster than the normal 8.
///
/// This is based off the algorithm described in "Fast numeric string to
/// int", available here: <https://johnnylee-sde.github.io/Fast-numeric-string-to-int/>.
fn parse8Digits(v_: u64) u64 {
    var v = v_;
    const mask = 0x0000_00ff_0000_00ff;
    const mul1 = 0x000f_4240_0000_0064;
    const mul2 = 0x0000_2710_0000_0001;
    v -= 0x3030_3030_3030_3030;
    v = (v * 10) + (v >> 8); // will not overflow, fits in 63 bits
    const v1 = (v & mask) *% mul1;
    const v2 = ((v >> 16) & mask) *% mul2;
    return @as(u64, @as(u32, @truncate((v1 +% v2) >> 32)));
}

/// Parse digits until a non-digit character is found.
fn tryParseDigits(comptime T: type, stream: *FloatStream, x: *T, comptime base: u8) void {
    // Try to parse 8 digits at a time, using an optimized algorithm.
    // This only supports decimal digits.
    if (base == 10) {
        while (stream.hasLen(8)) {
            const v = stream.readU64Unchecked();
            if (!isEightDigits(v)) {
                break;
            }

            x.* = x.* *% 1_0000_0000 +% parse8Digits(v);
            stream.advance(8);
        }
    }

    while (stream.scanDigit(base)) |digit| {
        x.* *%= base;
        x.* +%= digit;
    }
}

fn min_n_digit_int(comptime T: type, digit_count: usize) T {
    var n: T = 1;
    var i: usize = 1;
    while (i < digit_count) : (i += 1) n *= 10;
    return n;
}

/// Parse up to N digits
fn tryParseNDigits(comptime T: type, stream: *FloatStream, x: *T, comptime base: u8, comptime n: usize) void {
    while (x.* < min_n_digit_int(T, n)) {
        if (stream.scanDigit(base)) |digit| {
            x.* *%= base;
            x.* +%= digit;
        } else {
            break;
        }
    }
}

/// Parse the scientific notation component of a float.
fn parseScientific(stream: *FloatStream) ?i64 {
    var exponent: i64 = 0;
    var negative = false;

    if (stream.first()) |c| {
        negative = c == '-';
        if (c == '-' or c == '+') {
            stream.advance(1);
        }
    }
    if (stream.firstIsDigit(10)) {
        while (stream.scanDigit(10)) |digit| {
            // no overflows here, saturate well before overflow
            if (exponent < 0x1000_0000) {
                exponent = 10 * exponent + digit;
            }
        }

        return if (negative) -exponent else exponent;
    }

    return null;
}

const ParseInfo = struct {
    // 10 or 16
    base: u8,
    // 10^19 fits in u64, 16^16 fits in u64
    max_mantissa_digits: usize,
    // e.g. e or p (E and P also checked)
    exp_char_lower: u8,
};

fn parsePartialNumberBase(comptime T: type, stream: *FloatStream, negative: bool, n: *usize, comptime info: ParseInfo) ?Number(T) {
    std.debug.assert(info.base == 10 or info.base == 16);
    const MantissaT = common.mantissaType(T);

    // parse initial digits before dot
    var mantissa: MantissaT = 0;
    tryParseDigits(MantissaT, stream, &mantissa, info.base);
    const int_end = stream.offsetTrue();
    var n_digits = @as(isize, @intCast(stream.offsetTrue()));

    // handle dot with the following digits
    var exponent: i64 = 0;
    if (stream.firstIs(".")) {
        stream.advance(1);
        const marker = stream.offsetTrue();
        tryParseDigits(MantissaT, stream, &mantissa, info.base);
        const n_after_dot = stream.offsetTrue() - marker;
        exponent = -@as(i64, @intCast(n_after_dot));
        n_digits += @as(isize, @intCast(n_after_dot));
    }

    // adjust required shift to offset mantissa for base-16 (2^4)
    if (info.base == 16) {
        exponent *= 4;
    }

    if (n_digits == 0) {
        return null;
    }

    // handle scientific format
    var exp_number: i64 = 0;
    if (stream.firstIsLower(&.{info.exp_char_lower})) {
        stream.advance(1);
        exp_number = parseScientific(stream) orelse return null;
        exponent += exp_number;
    }

    const len = stream.offset; // length must be complete parsed length
    n.* += len;

    if (stream.underscore_count > 0 and !validUnderscores(stream.slice, info.base)) {
        return null;
    }

    // common case with not many digits
    if (n_digits <= info.max_mantissa_digits) {
        return Number(T){
            .exponent = exponent,
            .mantissa = mantissa,
            .negative = negative,
            .many_digits = false,
            .hex = info.base == 16,
        };
    }

    n_digits -= info.max_mantissa_digits;
    var many_digits = false;
    stream.reset(); // re-parse from beginning
    while (stream.firstIs("0._")) {
        // '0' = '.' + 2
        const next = stream.firstUnchecked();
        if (next != '_') {
            n_digits -= @as(isize, @intCast(next -| ('0' - 1)));
        } else {
            stream.underscore_count += 1;
        }
        stream.advance(1);
    }
    if (n_digits > 0) {
        // at this point we have more than max_mantissa_digits significant digits, let's try again
        many_digits = true;
        mantissa = 0;
        stream.reset();
        tryParseNDigits(MantissaT, stream, &mantissa, info.base, info.max_mantissa_digits);

        exponent = blk: {
            if (mantissa >= min_n_digit_int(MantissaT, info.max_mantissa_digits)) {
                // big int
                break :blk @as(i64, @intCast(int_end)) - @as(i64, @intCast(stream.offsetTrue()));
            } else {
                // the next byte must be present and be '.'
                // We know this is true because we had more than 19
                // digits previously, so we overflowed a 64-bit integer,
                // but parsing only the integral digits produced less
                // than 19 digits. That means we must have a decimal
                // point, and at least 1 fractional digit.
                stream.advance(1);
                const marker = stream.offsetTrue();
                tryParseNDigits(MantissaT, stream, &mantissa, info.base, info.max_mantissa_digits);
                break :blk @as(i64, @intCast(marker)) - @as(i64, @intCast(stream.offsetTrue()));
            }
        };
        if (info.base == 16) {
            exponent *= 4;
        }
        // add back the explicit part
        exponent += exp_number;
    }

    return Number(T){
        .exponent = exponent,
        .mantissa = mantissa,
        .negative = negative,
        .many_digits = many_digits,
        .hex = info.base == 16,
    };
}

/// Parse a partial, non-special floating point number.
///
/// This creates a representation of the float as the
/// significant digits and the decimal exponent.
fn parsePartialNumber(comptime T: type, s: []const u8, negative: bool, n: *usize) ?Number(T) {
    std.debug.assert(s.len != 0);
    const MantissaT = common.mantissaType(T);
    n.* = 0;

    if (s.len >= 2 and s[0] == '0' and std.ascii.toLower(s[1]) == 'x') {
        var stream = FloatStream.init(s[2..]);
        n.* += 2;
        return parsePartialNumberBase(T, &stream, negative, n, .{
            .base = 16,
            .max_mantissa_digits = if (MantissaT == u64) 16 else 32,
            .exp_char_lower = 'p',
        });
    } else {
        var stream = FloatStream.init(s);
        return parsePartialNumberBase(T, &stream, negative, n, .{
            .base = 10,
            .max_mantissa_digits = if (MantissaT == u64) 19 else 38,
            .exp_char_lower = 'e',
        });
    }
}

pub fn parseNumber(comptime T: type, s: []const u8, negative: bool) ?Number(T) {
    var consumed: usize = 0;
    if (parsePartialNumber(T, s, negative, &consumed)) |number| {
        // must consume entire float (no trailing data)
        if (s.len == consumed) {
            return number;
        }
    }
    return null;
}

fn parsePartialInfOrNan(comptime T: type, s: []const u8, negative: bool, n: *usize) ?T {
    // inf/infinity; infxxx should only consume inf.
    if (std.ascii.startsWithIgnoreCase(s, "inf")) {
        n.* = 3;
        if (std.ascii.startsWithIgnoreCase(s[3..], "inity")) {
            n.* = 8;
        }

        return if (!negative) std.math.inf(T) else -std.math.inf(T);
    }

    if (std.ascii.startsWithIgnoreCase(s, "nan")) {
        n.* = 3;
        return std.math.nan(T);
    }

    return null;
}

pub fn parseInfOrNan(comptime T: type, s: []const u8, negative: bool) ?T {
    var consumed: usize = 0;
    if (parsePartialInfOrNan(T, s, negative, &consumed)) |special| {
        if (s.len == consumed) {
            return special;
        }
    }
    return null;
}

pub fn validUnderscores(s: []const u8, comptime base: u8) bool {
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (s[i] == '_') {
            // underscore at start of end
            if (i == 0 or i + 1 == s.len) {
                return false;
            }
            // consecutive underscores
            if (!common.isDigit(s[i - 1], base) or !common.isDigit(s[i + 1], base)) {
                return false;
            }

            // next is guaranteed a digit, skip an extra
            i += 1;
        }
    }

    return true;
}

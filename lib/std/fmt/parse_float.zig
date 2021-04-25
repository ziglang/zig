// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Adapted from https://github.com/grzegorz-kraszewski/stringtofloat.

// MIT License
//
// Copyright (c) 2016 Grzegorz Kraszewski
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

// Be aware that this implementation has the following limitations:
//
// - Is not round-trip accurate for all values
// - Only supports round-to-zero
// - Does not handle denormals

const std = @import("../std.zig");
const ascii = std.ascii;

// The mantissa field in FloatRepr is 64bit wide and holds only 19 digits
// without overflowing
const max_digits = 19;

const f64_plus_zero: u64 = 0x0000000000000000;
const f64_minus_zero: u64 = 0x8000000000000000;
const f64_plus_infinity: u64 = 0x7FF0000000000000;
const f64_minus_infinity: u64 = 0xFFF0000000000000;

const Z96 = struct {
    d0: u32,
    d1: u32,
    d2: u32,

    // d = s >> 1
    fn shiftRight1(d: *Z96, s: Z96) callconv(.Inline) void {
        d.d0 = (s.d0 >> 1) | ((s.d1 & 1) << 31);
        d.d1 = (s.d1 >> 1) | ((s.d2 & 1) << 31);
        d.d2 = s.d2 >> 1;
    }

    // d = s << 1
    fn shiftLeft1(d: *Z96, s: Z96) callconv(.Inline) void {
        d.d2 = (s.d2 << 1) | ((s.d1 & (1 << 31)) >> 31);
        d.d1 = (s.d1 << 1) | ((s.d0 & (1 << 31)) >> 31);
        d.d0 = s.d0 << 1;
    }

    // d += s
    fn add(d: *Z96, s: Z96) callconv(.Inline) void {
        var w = @as(u64, d.d0) + @as(u64, s.d0);
        d.d0 = @truncate(u32, w);

        w >>= 32;
        w += @as(u64, d.d1) + @as(u64, s.d1);
        d.d1 = @truncate(u32, w);

        w >>= 32;
        w += @as(u64, d.d2) + @as(u64, s.d2);
        d.d2 = @truncate(u32, w);
    }

    // d -= s
    fn sub(d: *Z96, s: Z96) callconv(.Inline) void {
        var w = @as(u64, d.d0) -% @as(u64, s.d0);
        d.d0 = @truncate(u32, w);

        w >>= 32;
        w += @as(u64, d.d1) -% @as(u64, s.d1);
        d.d1 = @truncate(u32, w);

        w >>= 32;
        w += @as(u64, d.d2) -% @as(u64, s.d2);
        d.d2 = @truncate(u32, w);
    }
};

const FloatRepr = struct {
    negative: bool,
    exponent: i32,
    mantissa: u64,
};

fn convertRepr(comptime T: type, n: FloatRepr) T {
    const mask28: u32 = 0xf << 28;

    var s: Z96 = undefined;
    var q: Z96 = undefined;
    var r: Z96 = undefined;

    s.d0 = @truncate(u32, n.mantissa);
    s.d1 = @truncate(u32, n.mantissa >> 32);
    s.d2 = 0;

    var binary_exponent: i32 = 92;
    var exp = n.exponent;

    while (exp > 0) : (exp -= 1) {
        q.shiftLeft1(s); // q = p << 1
        r.shiftLeft1(q); // r = p << 2
        s.shiftLeft1(r); // p = p << 3
        s.add(q); // p = (p << 3) + (p << 1)

        while (s.d2 & mask28 != 0) {
            q.shiftRight1(s);
            binary_exponent += 1;
            s = q;
        }
    }

    while (exp < 0) {
        while (s.d2 & (1 << 31) == 0) {
            q.shiftLeft1(s);
            binary_exponent -= 1;
            s = q;
        }

        q.d2 = s.d2 / 10;
        r.d1 = s.d2 % 10;
        r.d2 = (s.d1 >> 8) | (r.d1 << 24);
        q.d1 = r.d2 / 10;
        r.d1 = r.d2 % 10;
        r.d2 = ((s.d1 & 0xff) << 16) | (s.d0 >> 16) | (r.d1 << 24);
        r.d0 = r.d2 / 10;
        r.d1 = r.d2 % 10;
        q.d1 = (q.d1 << 8) | ((r.d0 & 0x00ff0000) >> 16);
        q.d0 = r.d0 << 16;
        r.d2 = (s.d0 *% 0xffff) | (r.d1 << 16);
        q.d0 |= r.d2 / 10;
        s = q;

        exp += 1;
    }

    if (s.d0 != 0 or s.d1 != 0 or s.d2 != 0) {
        while (s.d2 & mask28 == 0) {
            q.shiftLeft1(s);
            binary_exponent -= 1;
            s = q;
        }
    }

    binary_exponent += 1023;

    const repr: u64 = blk: {
        if (binary_exponent > 2046) {
            break :blk if (n.negative) f64_minus_infinity else f64_plus_infinity;
        } else if (binary_exponent < 1) {
            break :blk if (n.negative) f64_minus_zero else f64_plus_zero;
        } else if (s.d2 != 0) {
            const binexs2 = @intCast(u64, binary_exponent) << 52;
            const rr = (@as(u64, s.d2 & ~mask28) << 24) | ((@as(u64, s.d1) + 128) >> 8) | binexs2;
            break :blk if (n.negative) rr | (1 << 63) else rr;
        } else {
            break :blk 0;
        }
    };

    const f = @bitCast(f64, repr);
    return @floatCast(T, f);
}

const State = enum {
    MaybeSign,
    LeadingMantissaZeros,
    LeadingFractionalZeros,
    MantissaIntegral,
    MantissaFractional,
    ExponentSign,
    LeadingExponentZeros,
    Exponent,
};

const ParseResult = enum {
    Ok,
    PlusZero,
    MinusZero,
    PlusInf,
    MinusInf,
};

fn parseRepr(s: []const u8, n: *FloatRepr) !ParseResult {
    var digit_index: usize = 0;
    var negative = false;
    var negative_exp = false;
    var exponent: i32 = 0;

    var state = State.MaybeSign;

    var i: usize = 0;
    while (i < s.len) {
        const c = s[i];

        switch (state) {
            .MaybeSign => {
                state = .LeadingMantissaZeros;

                if (c == '+') {
                    i += 1;
                } else if (c == '-') {
                    n.negative = true;
                    i += 1;
                } else if (ascii.isDigit(c) or c == '.') {
                    // continue
                } else {
                    return error.InvalidCharacter;
                }
            },
            .LeadingMantissaZeros => {
                if (c == '0') {
                    i += 1;
                } else if (c == '.') {
                    i += 1;
                    state = .LeadingFractionalZeros;
                } else {
                    state = .MantissaIntegral;
                }
            },
            .LeadingFractionalZeros => {
                if (c == '0') {
                    i += 1;
                    if (n.exponent > std.math.minInt(i32)) {
                        n.exponent -= 1;
                    }
                } else {
                    state = .MantissaFractional;
                }
            },
            .MantissaIntegral => {
                if (ascii.isDigit(c)) {
                    if (digit_index < max_digits) {
                        n.mantissa *%= 10;
                        n.mantissa += c - '0';
                        digit_index += 1;
                    } else if (n.exponent < std.math.maxInt(i32)) {
                        n.exponent += 1;
                    }

                    i += 1;
                } else if (c == '.') {
                    i += 1;
                    state = .MantissaFractional;
                } else {
                    state = .MantissaFractional;
                }
            },
            .MantissaFractional => {
                if (ascii.isDigit(c)) {
                    if (digit_index < max_digits) {
                        n.mantissa *%= 10;
                        n.mantissa += c - '0';
                        n.exponent -%= 1;
                        digit_index += 1;
                    }

                    i += 1;
                } else if (c == 'e' or c == 'E') {
                    i += 1;
                    state = .ExponentSign;
                } else {
                    state = .ExponentSign;
                }
            },
            .ExponentSign => {
                if (c == '+') {
                    i += 1;
                } else if (c == '-') {
                    negative_exp = true;
                    i += 1;
                }

                state = .LeadingExponentZeros;
            },
            .LeadingExponentZeros => {
                if (c == '0') {
                    i += 1;
                } else {
                    state = .Exponent;
                }
            },
            .Exponent => {
                if (ascii.isDigit(c)) {
                    if (exponent < std.math.maxInt(i32) / 10) {
                        exponent *= 10;
                        exponent += @intCast(i32, c - '0');
                    }

                    i += 1;
                } else {
                    return error.InvalidCharacter;
                }
            },
        }
    }

    if (negative_exp) exponent = -exponent;
    n.exponent += exponent;

    if (n.mantissa == 0) {
        return if (n.negative) .MinusZero else .PlusZero;
    } else if (n.exponent > 309) {
        return if (n.negative) .MinusInf else .PlusInf;
    } else if (n.exponent < -328) {
        return if (n.negative) .MinusZero else .PlusZero;
    }

    return .Ok;
}

fn caseInEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;

    for (a) |_, i| {
        if (ascii.toUpper(a[i]) != ascii.toUpper(b[i])) {
            return false;
        }
    }

    return true;
}

pub fn parseFloat(comptime T: type, s: []const u8) !T {
    if (s.len == 0 or (s.len == 1 and (s[0] == '+' or s[0] == '-'))) {
        return error.InvalidCharacter;
    }

    if (caseInEql(s, "nan")) {
        return std.math.nan(T);
    } else if (caseInEql(s, "inf") or caseInEql(s, "+inf")) {
        return std.math.inf(T);
    } else if (caseInEql(s, "-inf")) {
        return -std.math.inf(T);
    }

    var r = FloatRepr{
        .negative = false,
        .exponent = 0,
        .mantissa = 0,
    };

    return switch (try parseRepr(s, &r)) {
        .Ok => convertRepr(T, r),
        .PlusZero => 0.0,
        .MinusZero => -@as(T, 0.0),
        .PlusInf => std.math.inf(T),
        .MinusInf => -std.math.inf(T),
    };
}

test "fmt.parseFloat" {
    const testing = std.testing;
    const expect = testing.expect;
    const expectEqual = testing.expectEqual;
    const approxEqAbs = std.math.approxEqAbs;
    const epsilon = 1e-7;

    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        const Z = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);

        testing.expectError(error.InvalidCharacter, parseFloat(T, ""));
        testing.expectError(error.InvalidCharacter, parseFloat(T, "   1"));
        testing.expectError(error.InvalidCharacter, parseFloat(T, "1abc"));
        testing.expectError(error.InvalidCharacter, parseFloat(T, "+"));
        testing.expectError(error.InvalidCharacter, parseFloat(T, "-"));

        expectEqual(try parseFloat(T, "0"), 0.0);
        expectEqual(try parseFloat(T, "0"), 0.0);
        expectEqual(try parseFloat(T, "+0"), 0.0);
        expectEqual(try parseFloat(T, "-0"), 0.0);

        expectEqual(try parseFloat(T, "0e0"), 0);
        expectEqual(try parseFloat(T, "2e3"), 2000.0);
        expectEqual(try parseFloat(T, "1e0"), 1.0);
        expectEqual(try parseFloat(T, "-2e3"), -2000.0);
        expectEqual(try parseFloat(T, "-1e0"), -1.0);
        expectEqual(try parseFloat(T, "1.234e3"), 1234);

        expect(approxEqAbs(T, try parseFloat(T, "3.141"), 3.141, epsilon));
        expect(approxEqAbs(T, try parseFloat(T, "-3.141"), -3.141, epsilon));

        expectEqual(try parseFloat(T, "1e-700"), 0);
        expectEqual(try parseFloat(T, "1e+700"), std.math.inf(T));

        expectEqual(@bitCast(Z, try parseFloat(T, "nAn")), @bitCast(Z, std.math.nan(T)));
        expectEqual(try parseFloat(T, "inF"), std.math.inf(T));
        expectEqual(try parseFloat(T, "-INF"), -std.math.inf(T));

        expectEqual(try parseFloat(T, "0.4e0066999999999999999999999999999999999999999999999999999"), std.math.inf(T));

        if (T != f16) {
            expect(approxEqAbs(T, try parseFloat(T, "1e-2"), 0.01, epsilon));
            expect(approxEqAbs(T, try parseFloat(T, "1234e-2"), 12.34, epsilon));

            expect(approxEqAbs(T, try parseFloat(T, "123142.1"), 123142.1, epsilon));
            expect(approxEqAbs(T, try parseFloat(T, "-123142.1124"), @as(T, -123142.1124), epsilon));
            expect(approxEqAbs(T, try parseFloat(T, "0.7062146892655368"), @as(T, 0.7062146892655368), epsilon));
            expect(approxEqAbs(T, try parseFloat(T, "2.71828182845904523536"), @as(T, 2.718281828459045), epsilon));
        }
    }
}

const F128 = packed struct {
    mantissa: u112,
    exponent: u15,
    sign: u1,
};

pub fn parseHexFloat(bytes: []const u8) !f128 {
    if (bytes.len < 6)
        return error.InvalidCharacter;

    var start: usize = 0;
    const sign: u1 = switch (bytes[0]) {
        '+', '-' => |val| blk: {
            start += 1;
            break :blk if (val == '-') @as(u1, 1) else @as(u1, 0);
        },
        '0' => 0,
        else => return error.InvalidCharacter,
    };

    if (!std.mem.startsWith(u8, bytes[start..], "0x"))
        return error.InvalidCharacter;

    start += 2;
    var it = std.mem.split(bytes[start..], ".");
    const whole_str = it.next() orelse return error.InvalidCharacter;
    const tmp = it.next() orelse return error.InvalidCharacter;

    if (it.next() != null) return error.InvalidCharacter;

    it = std.mem.split(tmp, "p");
    const decimal_str = it.next() orelse return error.InvalidCharacter;
    const exp_str = it.next() orelse return error.InvalidCharacter;

    if (it.next() != null) return error.InvalidCharacter;

    // count leading zeros
    var leading_zeroes: usize = 0;
    for (decimal_str) |c| {
        if (c != '0') break;

        leading_zeroes += 1;
    }

    const whole = if (whole_str.len > 0)
        try std.fmt.parseUnsigned(u113, whole_str, 16)
    else
        return error.InvalidCharacter;
    const decimal = if (decimal_str.len > 0)
        try std.fmt.parseUnsigned(u113, decimal_str, 16)
    else
        0;

    // calculating mantissa might alter exp
    var exp = try std.fmt.parseInt(i15, exp_str, 10);
    const mantissa: u112 = if (whole > 0) blk: {
        const leading_bits = @clz(u113, whole);
        exp += 113 - leading_bits - 1;
        break :blk @truncate(u112, whole << leading_bits) |
            @truncate(u112, decimal << leading_bits - (@intCast(u7, decimal_str.len * 4)));
    } else blk: {
        const leading_bits = @clz(u113, decimal);
        exp -= 1 +
            (@intCast(i15, leading_zeroes) * 4) +
            @clz(u4, @truncate(u4, try std.fmt.charToDigit(decimal_str[leading_zeroes], 16)));
        break :blk @truncate(u112, decimal << leading_bits);
    };

    return @bitCast(f128, F128{
        .sign = sign,
        .exponent = @bitCast(u15, exp) +% 0x3fff,
        .mantissa = mantissa,
    });
}

test "fmt.parseHexFloat" {
    const expectEqual = std.testing.expectEqual;

    expectEqual(@as(f128, 0x1.p3), try parseHexFloat("0x1.p3"));
    expectEqual(@as(f128, 0x1.fp3), try parseHexFloat("0x1.fp3"));
    expectEqual(@as(f128, 0x3.fp3), try parseHexFloat("0x3.fp3"));
    expectEqual(@as(f128, 0x0f0.0fp3), try parseHexFloat("0x0f0.0fp3"));

    expectEqual(@as(f128, 0x1.p3), try parseHexFloat("+0x1.p3"));
    expectEqual(@as(f128, 0x1.fp3), try parseHexFloat("+0x1.fp3"));
    expectEqual(@as(f128, 0x3.fp3), try parseHexFloat("+0x3.fp3"));
    expectEqual(@as(f128, 0x0f0.0fp3), try parseHexFloat("+0x0f0.0fp3"));

    expectEqual(@as(f128, -0x1.p3), try parseHexFloat("-0x1.p3"));
    expectEqual(@as(f128, -0x1.fp3), try parseHexFloat("-0x1.fp3"));
    expectEqual(@as(f128, -0x3.fp3), try parseHexFloat("-0x3.fp3"));
    expectEqual(@as(f128, -0x0f0.0fp3), try parseHexFloat("-0x0f0.0fp3"));

    expectEqual(@as(f128, 0x1.p-3), try parseHexFloat("0x1.p-3"));
    expectEqual(@as(f128, 0x1.fp-3), try parseHexFloat("0x1.fp-3"));
    expectEqual(@as(f128, 0x3.fp-3), try parseHexFloat("0x3.fp-3"));
    expectEqual(@as(f128, 0x0f0.0fp-3), try parseHexFloat("0x0f0.0fp-3"));
}

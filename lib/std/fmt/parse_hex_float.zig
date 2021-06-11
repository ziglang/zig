// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.const std = @import("std");
//
// The rounding logic is inspired by LLVM's APFloat and Go's atofHex
// implementation.

const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;
const math = std.math;
const testing = std.testing;

const assert = std.debug.assert;

pub fn parseHexFloat(comptime T: type, s: []const u8) !T {
    assert(@typeInfo(T) == .Float);

    const IntT = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);

    const mantissa_bits = math.floatMantissaBits(T);
    const exponent_bits = math.floatExponentBits(T);

    const sign_shift = mantissa_bits + exponent_bits;

    const exponent_bias = (1 << (exponent_bits - 1)) - 1;
    const exponent_min = 1 - exponent_bias;
    const exponent_max = exponent_bias;

    if (s.len == 0)
        return error.InvalidCharacter;

    if (ascii.eqlIgnoreCase(s, "nan")) {
        return math.nan(T);
    } else if (ascii.eqlIgnoreCase(s, "inf") or ascii.eqlIgnoreCase(s, "+inf")) {
        return math.inf(T);
    } else if (ascii.eqlIgnoreCase(s, "-inf")) {
        return -math.inf(T);
    }

    var negative: bool = false;
    var exp_negative: bool = false;

    var mantissa: u128 = 0;
    var exponent: i16 = 0;
    var frac_scale: i16 = 0;

    const State = enum {
        MaybeSign,
        Prefix,
        LeadingIntegerDigit,
        IntegerDigit,
        MaybeDot,
        LeadingFractionDigit,
        FractionDigit,
        ExpPrefix,
        MaybeExpSign,
        ExpDigit,
    };

    var state = State.MaybeSign;

    var i: usize = 0;
    while (i < s.len) {
        const c = s[i];

        switch (state) {
            .MaybeSign => {
                state = .Prefix;

                if (c == '+') {
                    i += 1;
                } else if (c == '-') {
                    negative = true;
                    i += 1;
                }
            },
            .Prefix => {
                state = .LeadingIntegerDigit;

                // Match both 0x and 0X.
                if (i + 2 > s.len or s[i] != '0' or s[i + 1] | 32 != 'x')
                    return error.InvalidCharacter;
                i += 2;
            },
            .LeadingIntegerDigit => {
                if (c == '0') {
                    // Skip leading zeros.
                    i += 1;
                } else if (c == '_') {
                    return error.InvalidCharacter;
                } else {
                    state = .IntegerDigit;
                }
            },
            .IntegerDigit => {
                if (ascii.isXDigit(c)) {
                    if (mantissa >= math.maxInt(u128) / 16)
                        return error.Overflow;
                    mantissa *%= 16;
                    mantissa += try fmt.charToDigit(c, 16);
                    i += 1;
                } else if (c == '_') {
                    i += 1;
                } else {
                    state = .MaybeDot;
                }
            },
            .MaybeDot => {
                if (c == '.') {
                    state = .LeadingFractionDigit;
                    i += 1;
                } else state = .ExpPrefix;
            },
            .LeadingFractionDigit => {
                if (c == '_') {
                    return error.InvalidCharacter;
                } else state = .FractionDigit;
            },
            .FractionDigit => {
                if (ascii.isXDigit(c)) {
                    if (mantissa < math.maxInt(u128) / 16) {
                        mantissa *%= 16;
                        mantissa +%= try fmt.charToDigit(c, 16);
                        frac_scale += 1;
                    } else if (c != '0') {
                        return error.Overflow;
                    }
                    i += 1;
                } else if (c == '_') {
                    i += 1;
                } else {
                    state = .ExpPrefix;
                }
            },
            .ExpPrefix => {
                state = .MaybeExpSign;
                // Match both p and P.
                if (c | 32 != 'p')
                    return error.InvalidCharacter;
                i += 1;
            },
            .MaybeExpSign => {
                state = .ExpDigit;

                if (c == '+') {
                    i += 1;
                } else if (c == '-') {
                    exp_negative = true;
                    i += 1;
                }
            },
            .ExpDigit => {
                if (ascii.isXDigit(c)) {
                    if (exponent >= math.maxInt(i16) / 10)
                        return error.Overflow;
                    exponent *%= 10;
                    exponent +%= try fmt.charToDigit(c, 10);
                    i += 1;
                } else if (c == '_') {
                    i += 1;
                } else {
                    return error.InvalidCharacter;
                }
            },
        }
    }

    if (exp_negative)
        exponent *= -1;

    // Bring the decimal part to the left side of the decimal dot.
    exponent -= frac_scale * 4;

    if (mantissa == 0) {
        // Signed zero.
        return if (negative) -0.0 else 0.0;
    }

    // Divide by 2^mantissa_bits to right-align the mantissa in the fractional
    // part.
    exponent += mantissa_bits;

    // Keep around two extra bits to correctly round any value that doesn't fit
    // the available mantissa bits. The result LSB serves as Guard bit, the
    // following one is the Round bit and the last one is the Sticky bit,
    // computed by OR-ing all the dropped bits.

    // Normalize by aligning the implicit one bit.
    while (mantissa >> (mantissa_bits + 2) == 0) {
        mantissa <<= 1;
        exponent -= 1;
    }

    // Normalize again by dropping the excess precision.
    // Note that the discarded bits are folded into the Sticky bit.
    while (mantissa >> (mantissa_bits + 2 + 1) != 0) {
        mantissa = mantissa >> 1 | (mantissa & 1);
        exponent += 1;
    }

    // Very small numbers can be possibly represented as denormals, reduce the
    // exponent as much as possible.
    while (mantissa != 0 and exponent < exponent_min - 2) {
        mantissa = mantissa >> 1 | (mantissa & 1);
        exponent += 1;
    }

    // There are two cases to handle:
    // - We've truncated more than 0.5ULP (R=S=1), increase the mantissa.
    // - We've truncated exactly 0.5ULP (R=1 S=0), increase the mantissa if the
    //   result is odd (G=1).
    // The two checks can be neatly folded as follows.
    mantissa |= @boolToInt(mantissa & 0b100 != 0);
    mantissa += 1;

    mantissa >>= 2;
    exponent += 2;

    if (mantissa & (1 << (mantissa_bits + 1)) != 0) {
        // Renormalize, if the exponent overflows we'll catch that below.
        mantissa >>= 1;
        exponent += 1;
    }

    if (mantissa >> mantissa_bits == 0) {
        // This is a denormal number, the biased exponent is zero.
        exponent = -exponent_bias;
    }

    if (exponent > exponent_max) {
        // Overflow, return +inf.
        return math.inf(T);
    }

    // Remove the implicit bit.
    mantissa &= @as(u128, (1 << mantissa_bits) - 1);

    const raw: IntT =
        (if (negative) @as(IntT, 1) << sign_shift else 0) |
        @as(IntT, @bitCast(u16, exponent + exponent_bias)) << mantissa_bits |
        @truncate(IntT, mantissa);

    return @bitCast(T, raw);
}

test "special" {
    try testing.expect(math.isNan(try parseHexFloat(f32, "nAn")));
    try testing.expect(math.isPositiveInf(try parseHexFloat(f32, "iNf")));
    try testing.expect(math.isPositiveInf(try parseHexFloat(f32, "+Inf")));
    try testing.expect(math.isNegativeInf(try parseHexFloat(f32, "-iNf")));
}
test "zero" {
    try testing.expectEqual(@as(f32, 0.0), try parseHexFloat(f32, "0x0"));
    try testing.expectEqual(@as(f32, 0.0), try parseHexFloat(f32, "-0x0"));
    try testing.expectEqual(@as(f32, 0.0), try parseHexFloat(f32, "0x0p42"));
    try testing.expectEqual(@as(f32, 0.0), try parseHexFloat(f32, "-0x0.00000p42"));
    try testing.expectEqual(@as(f32, 0.0), try parseHexFloat(f32, "0x0.00000p666"));
}

test "f16" {
    const Case = struct { s: []const u8, v: f16 };
    const cases: []const Case = &[_]Case{
        .{ .s = "0x1p0", .v = 1.0 },
        .{ .s = "-0x1p-1", .v = -0.5 },
        .{ .s = "0x10p+10", .v = 16384.0 },
        .{ .s = "0x10p-10", .v = 0.015625 },
        // Max normalized value.
        .{ .s = "0x1.ffcp+15", .v = math.f16_max },
        .{ .s = "-0x1.ffcp+15", .v = -math.f16_max },
        // Min normalized value.
        .{ .s = "0x1p-14", .v = math.f16_min },
        .{ .s = "-0x1p-14", .v = -math.f16_min },
        // Min denormal value.
        .{ .s = "0x1p-24", .v = math.f16_true_min },
        .{ .s = "-0x1p-24", .v = -math.f16_true_min },
    };

    for (cases) |case| {
        try testing.expectEqual(case.v, try parseHexFloat(f16, case.s));
    }
}
test "f32" {
    const Case = struct { s: []const u8, v: f32 };
    const cases: []const Case = &[_]Case{
        .{ .s = "0x1p0", .v = 1.0 },
        .{ .s = "-0x1p-1", .v = -0.5 },
        .{ .s = "0x10p+10", .v = 16384.0 },
        .{ .s = "0x10p-10", .v = 0.015625 },
        .{ .s = "0x0.ffffffp128", .v = 0x0.ffffffp128 },
        .{ .s = "0x0.1234570p-125", .v = 0x0.1234570p-125 },
        // Max normalized value.
        .{ .s = "0x1.fffffeP+127", .v = math.f32_max },
        .{ .s = "-0x1.fffffeP+127", .v = -math.f32_max },
        // Min normalized value.
        .{ .s = "0x1p-126", .v = math.f32_min },
        .{ .s = "-0x1p-126", .v = -math.f32_min },
        // Min denormal value.
        .{ .s = "0x1P-149", .v = math.f32_true_min },
        .{ .s = "-0x1P-149", .v = -math.f32_true_min },
    };

    for (cases) |case| {
        try testing.expectEqual(case.v, try parseHexFloat(f32, case.s));
    }
}
test "f64" {
    const Case = struct { s: []const u8, v: f64 };
    const cases: []const Case = &[_]Case{
        .{ .s = "0x1p0", .v = 1.0 },
        .{ .s = "-0x1p-1", .v = -0.5 },
        .{ .s = "0x10p+10", .v = 16384.0 },
        .{ .s = "0x10p-10", .v = 0.015625 },
        // Max normalized value.
        .{ .s = "0x1.fffffffffffffp+1023", .v = math.f64_max },
        .{ .s = "-0x1.fffffffffffffp1023", .v = -math.f64_max },
        // Min normalized value.
        .{ .s = "0x1p-1022", .v = math.f64_min },
        .{ .s = "-0x1p-1022", .v = -math.f64_min },
        // Min denormalized value.
        .{ .s = "0x1p-1074", .v = math.f64_true_min },
        .{ .s = "-0x1p-1074", .v = -math.f64_true_min },
    };

    for (cases) |case| {
        try testing.expectEqual(case.v, try parseHexFloat(f64, case.s));
    }
}
test "f128" {
    const Case = struct { s: []const u8, v: f128 };
    const cases: []const Case = &[_]Case{
        .{ .s = "0x1p0", .v = 1.0 },
        .{ .s = "-0x1p-1", .v = -0.5 },
        .{ .s = "0x10p+10", .v = 16384.0 },
        .{ .s = "0x10p-10", .v = 0.015625 },
        // Max normalized value.
        .{ .s = "0xf.fffffffffffffffffffffffffff8p+16380", .v = math.f128_max },
        .{ .s = "-0xf.fffffffffffffffffffffffffff8p+16380", .v = -math.f128_max },
        // Min normalized value.
        .{ .s = "0x1p-16382", .v = math.f128_min },
        .{ .s = "-0x1p-16382", .v = -math.f128_min },
        // // Min denormalized value.
        .{ .s = "0x1p-16494", .v = math.f128_true_min },
        .{ .s = "-0x1p-16494", .v = -math.f128_true_min },
    };

    for (cases) |case| {
        try testing.expectEqual(@bitCast(u128, case.v), @bitCast(u128, try parseHexFloat(f128, case.s)));
    }
}

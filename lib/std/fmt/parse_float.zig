const std = @import("std");
const math = std.math;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;
const approxEqAbs = std.math.approxEqAbs;
const epsilon = 1e-7;
const parse = @import("parse_float/parse.zig");
const convertHex = @import("parse_float/convert_hex.zig").convertHex;
const convertFast = @import("parse_float/convert_fast.zig").convertFast;
const convertEiselLemire = @import("parse_float/convert_eisel_lemire.zig").convertEiselLemire;
const convertSlow = @import("parse_float/convert_slow.zig").convertSlow;

pub const ParseFloatError = error{
    InvalidCharacter,
};

pub fn parseFloat(comptime T: type, s: []const u8) ParseFloatError!T {
    if (@typeInfo(T) != .float) {
        @compileError("Cannot parse a float into a non-floating point type.");
    }

    if (s.len == 0) {
        return error.InvalidCharacter;
    }

    var i: usize = 0;
    const negative = s[i] == '-';
    if (s[i] == '-' or s[i] == '+') {
        i += 1;
    }
    if (s.len == i) {
        return error.InvalidCharacter;
    }

    const n = parse.parseNumber(T, s[i..], negative) orelse {
        return parse.parseInfOrNan(T, s[i..], negative) orelse error.InvalidCharacter;
    };

    if (n.hex) {
        return convertHex(T, n);
    }

    if (convertFast(T, n)) |f| {
        return f;
    }

    if (T == f16 or T == f32 or T == f64) {
        // If significant digits were truncated, then we can have rounding error
        // only if `mantissa + 1` produces a different result. We also avoid
        // redundantly using the Eisel-Lemire algorithm if it was unable to
        // correctly round on the first pass.
        if (convertEiselLemire(T, n.exponent, n.mantissa)) |bf| {
            if (!n.many_digits) {
                return bf.toFloat(T, n.negative);
            }
            if (convertEiselLemire(T, n.exponent, n.mantissa + 1)) |bf2| {
                if (bf.eql(bf2)) {
                    return bf.toFloat(T, n.negative);
                }
            }
        }
    }

    // Unable to correctly round the float using the Eisel-Lemire algorithm.
    // Fallback to a slower, but always correct algorithm.
    return convertSlow(T, s[i..]).toFloat(T, negative);
}

// See https://github.com/tiehuis/parse-number-fxx-test-data for a wider-selection of test-data.

test parseFloat {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        try testing.expectError(error.InvalidCharacter, parseFloat(T, ""));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "   1"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "1abc"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "+"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "-"));

        try expectEqual(try parseFloat(T, "0"), 0.0);
        try expectEqual(try parseFloat(T, "0"), 0.0);
        try expectEqual(try parseFloat(T, "+0"), 0.0);
        try expectEqual(try parseFloat(T, "-0"), 0.0);

        try expectEqual(try parseFloat(T, "0e0"), 0);
        try expectEqual(try parseFloat(T, "2e3"), 2000.0);
        try expectEqual(try parseFloat(T, "1e0"), 1.0);
        try expectEqual(try parseFloat(T, "-2e3"), -2000.0);
        try expectEqual(try parseFloat(T, "-1e0"), -1.0);
        try expectEqual(try parseFloat(T, "1.234e3"), 1234);

        try expect(approxEqAbs(T, try parseFloat(T, "3.141"), 3.141, epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, "-3.141"), -3.141, epsilon));

        try expectEqual(try parseFloat(T, "1e-5000"), 0);
        try expectEqual(try parseFloat(T, "1e+5000"), std.math.inf(T));

        try expectEqual(try parseFloat(T, "0.4e0066999999999999999999999999999999999999999999999999999"), std.math.inf(T));
        try expect(approxEqAbs(T, try parseFloat(T, "0_1_2_3_4_5_6.7_8_9_0_0_0e0_0_1_0"), @as(T, 123456.789000e10), epsilon));

        // underscore rule is simple and reduces to "can only occur between two digits" and multiple are not supported.
        try expectError(error.InvalidCharacter, parseFloat(T, "0123456.789000e_0010")); // cannot occur immediately after exponent
        try expectError(error.InvalidCharacter, parseFloat(T, "_0123456.789000e0010")); // cannot occur before any digits
        try expectError(error.InvalidCharacter, parseFloat(T, "0__123456.789000e_0010")); // cannot occur twice in a row
        try expectError(error.InvalidCharacter, parseFloat(T, "0123456_.789000e0010")); // cannot occur before decimal point
        try expectError(error.InvalidCharacter, parseFloat(T, "0123456.789000e0010_")); // cannot occur at end of number

        try expect(approxEqAbs(T, try parseFloat(T, "1e-2"), 0.01, epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, "1234e-2"), 12.34, epsilon));

        try expect(approxEqAbs(T, try parseFloat(T, "1."), 1, epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, "0."), 0, epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, ".1"), 0.1, epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, ".0"), 0, epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, ".1e-1"), 0.01, epsilon));

        try expectError(error.InvalidCharacter, parseFloat(T, ".")); // At least one digit is required.
        try expectError(error.InvalidCharacter, parseFloat(T, ".e1")); // At least one digit is required.
        try expectError(error.InvalidCharacter, parseFloat(T, "0.e")); // At least one digit is required.

        try expect(approxEqAbs(T, try parseFloat(T, "123142.1"), 123142.1, epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, "-123142.1124"), @as(T, -123142.1124), epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, "0.7062146892655368"), @as(T, 0.7062146892655368), epsilon));
        try expect(approxEqAbs(T, try parseFloat(T, "2.71828182845904523536"), @as(T, 2.718281828459045), epsilon));
    }
}

test "nan and inf" {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        const Z = std.meta.Int(.unsigned, @typeInfo(T).float.bits);

        try expectEqual(@as(Z, @bitCast(try parseFloat(T, "nAn"))), @as(Z, @bitCast(std.math.nan(T))));
        try expectEqual(try parseFloat(T, "inF"), std.math.inf(T));
        try expectEqual(try parseFloat(T, "-INF"), -std.math.inf(T));
    }
}

test "largest normals" {
    try expectEqual(@as(u16, @bitCast(try parseFloat(f16, "65504"))), 0x7bff);
    try expectEqual(@as(u32, @bitCast(try parseFloat(f32, "3.4028234664E38"))), 0x7f7f_ffff);
    try expectEqual(@as(u64, @bitCast(try parseFloat(f64, "1.7976931348623157E308"))), 0x7fef_ffff_ffff_ffff);
    try expectEqual(@as(u80, @bitCast(try parseFloat(f80, "1.189731495357231765E4932"))), 0x7ffe_ffff_ffff_ffff_ffff);
    try expectEqual(@as(u128, @bitCast(try parseFloat(f128, "1.1897314953572317650857593266280070162E4932"))), 0x7ffe_ffff_ffff_ffff_ffff_ffff_ffff_ffff);
}

test "#11169" {
    try expectEqual(try parseFloat(f128, "9007199254740993.0"), 9007199254740993.0);
}

test "many_digits hex" {
    const a: f32 = try parseFloat(f32, "0xffffffffffffffff.0p0");
    const b: f32 = @floatCast(try parseFloat(f128, "0xffffffffffffffff.0p0"));
    try std.testing.expectEqual(a, b);
}

test "hex.special" {
    try testing.expect(math.isNan(try parseFloat(f32, "nAn")));
    try testing.expect(math.isPositiveInf(try parseFloat(f32, "iNf")));
    try testing.expect(math.isPositiveInf(try parseFloat(f32, "+Inf")));
    try testing.expect(math.isNegativeInf(try parseFloat(f32, "-iNf")));
}

test "hex.zero" {
    try testing.expectEqual(@as(f32, 0.0), try parseFloat(f32, "0x0"));
    try testing.expectEqual(@as(f32, 0.0), try parseFloat(f32, "-0x0"));
    try testing.expectEqual(@as(f32, 0.0), try parseFloat(f32, "0x0p42"));
    try testing.expectEqual(@as(f32, 0.0), try parseFloat(f32, "-0x0.00000p42"));
    try testing.expectEqual(@as(f32, 0.0), try parseFloat(f32, "0x0.00000p666"));
}

test "hex.f16" {
    try testing.expectEqual(try parseFloat(f16, "0x1p0"), 1.0);
    try testing.expectEqual(try parseFloat(f16, "-0x1p-1"), -0.5);
    try testing.expectEqual(try parseFloat(f16, "0x10p+10"), 16384.0);
    try testing.expectEqual(try parseFloat(f16, "0x10p-10"), 0.015625);
    // Max normalized value.
    try testing.expectEqual(try parseFloat(f16, "0x1.ffcp+15"), math.floatMax(f16));
    try testing.expectEqual(try parseFloat(f16, "-0x1.ffcp+15"), -math.floatMax(f16));
    // Min normalized value.
    try testing.expectEqual(try parseFloat(f16, "0x1p-14"), math.floatMin(f16));
    try testing.expectEqual(try parseFloat(f16, "-0x1p-14"), -math.floatMin(f16));
    // Min denormal value.
    try testing.expectEqual(try parseFloat(f16, "0x1p-24"), math.floatTrueMin(f16));
    try testing.expectEqual(try parseFloat(f16, "-0x1p-24"), -math.floatTrueMin(f16));
}

test "hex.f32" {
    try testing.expectError(error.InvalidCharacter, parseFloat(f32, "0x"));
    try testing.expectEqual(try parseFloat(f32, "0x1p0"), 1.0);
    try testing.expectEqual(try parseFloat(f32, "-0x1p-1"), -0.5);
    try testing.expectEqual(try parseFloat(f32, "0x10p+10"), 16384.0);
    try testing.expectEqual(try parseFloat(f32, "0x10p-10"), 0.015625);
    try testing.expectEqual(try parseFloat(f32, "0x0.ffffffp128"), 0x0.ffffffp128);
    try testing.expectEqual(try parseFloat(f32, "0x0.1234570p-125"), 0x0.1234570p-125);
    // Max normalized value.
    try testing.expectEqual(try parseFloat(f32, "0x1.fffffeP+127"), math.floatMax(f32));
    try testing.expectEqual(try parseFloat(f32, "-0x1.fffffeP+127"), -math.floatMax(f32));
    // Min normalized value.
    try testing.expectEqual(try parseFloat(f32, "0x1p-126"), math.floatMin(f32));
    try testing.expectEqual(try parseFloat(f32, "-0x1p-126"), -math.floatMin(f32));
    // Min denormal value.
    try testing.expectEqual(try parseFloat(f32, "0x1P-149"), math.floatTrueMin(f32));
    try testing.expectEqual(try parseFloat(f32, "-0x1P-149"), -math.floatTrueMin(f32));
}

test "hex.f64" {
    try testing.expectEqual(try parseFloat(f64, "0x1p0"), 1.0);
    try testing.expectEqual(try parseFloat(f64, "-0x1p-1"), -0.5);
    try testing.expectEqual(try parseFloat(f64, "0x10p+10"), 16384.0);
    try testing.expectEqual(try parseFloat(f64, "0x10p-10"), 0.015625);
    // Max normalized value.
    try testing.expectEqual(try parseFloat(f64, "0x1.fffffffffffffp+1023"), math.floatMax(f64));
    try testing.expectEqual(try parseFloat(f64, "-0x1.fffffffffffffp1023"), -math.floatMax(f64));
    // Min normalized value.
    try testing.expectEqual(try parseFloat(f64, "0x1p-1022"), math.floatMin(f64));
    try testing.expectEqual(try parseFloat(f64, "-0x1p-1022"), -math.floatMin(f64));
    // Min denormalized value.
    try testing.expectEqual(try parseFloat(f64, "0x1p-1074"), math.floatTrueMin(f64));
    try testing.expectEqual(try parseFloat(f64, "-0x1p-1074"), -math.floatTrueMin(f64));
}

test "hex.f80" {
    try testing.expectEqual(try parseFloat(f80, "0x1p0"), 1.0);
    try testing.expectEqual(try parseFloat(f80, "-0x1p-1"), -0.5);
    try testing.expectEqual(try parseFloat(f80, "0x10p+10"), 16384.0);
    try testing.expectEqual(try parseFloat(f80, "0x10p-10"), 0.015625);
    // Max normalized value.
    try testing.expectEqual(try parseFloat(f80, "0xf.fffffffffffffff7p+16380"), math.floatMax(f80));
    try testing.expectEqual(try parseFloat(f80, "-0xf.fffffffffffffff7p+16380"), -math.floatMax(f80));
    // Min normalized value.
    try testing.expectEqual(try parseFloat(f80, "0x1p-16382"), math.floatMin(f80));
    try testing.expectEqual(try parseFloat(f80, "-0x1p-16382"), -math.floatMin(f80));
    // Min denormalized value.
    try testing.expectEqual(try parseFloat(f80, "0x1p-16445"), math.floatTrueMin(f80));
    try testing.expectEqual(try parseFloat(f80, "-0x1p-16445"), -math.floatTrueMin(f80));
}

test "hex.f128" {
    try testing.expectEqual(try parseFloat(f128, "0x1p0"), 1.0);
    try testing.expectEqual(try parseFloat(f128, "-0x1p-1"), -0.5);
    try testing.expectEqual(try parseFloat(f128, "0x10p+10"), 16384.0);
    try testing.expectEqual(try parseFloat(f128, "0x10p-10"), 0.015625);
    // Max normalized value.
    try testing.expectEqual(try parseFloat(f128, "0xf.fffffffffffffffffffffffffff8p+16380"), math.floatMax(f128));
    try testing.expectEqual(try parseFloat(f128, "-0xf.fffffffffffffffffffffffffff8p+16380"), -math.floatMax(f128));
    // Min normalized value.
    try testing.expectEqual(try parseFloat(f128, "0x1p-16382"), math.floatMin(f128));
    try testing.expectEqual(try parseFloat(f128, "-0x1p-16382"), -math.floatMin(f128));
    // Min denormalized value.
    try testing.expectEqual(try parseFloat(f128, "0x1p-16494"), math.floatTrueMin(f128));
    try testing.expectEqual(try parseFloat(f128, "-0x1p-16494"), -math.floatTrueMin(f128));
    // ensure round-to-even
    try testing.expectEqual(try parseFloat(f128, "0x1.edcb34a235253948765432134674fp-1"), 0x1.edcb34a235253948765432134674fp-1);
}

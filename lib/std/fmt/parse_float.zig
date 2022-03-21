//
// Adapted from sqlite3's sqlite3AtoF()
// https://github.com/mackyle/sqlite/blob/ae5d3aa91a794f6f1486b3f453ec44c0aa4c086b/src/util.c#L375-L571
//
// adds support for parsing f128 floats, "nan", "inf"
//
// Returns a float if the string is a valid number, or error.invalidCharacter
// if the string is empty or contains extraneous text.  Valid numbers
// are in one of these formats:
//
//    [+-]digits[E[+-]digits]
//    [+-]digits.[digits][E[+-]digits]
//    [+-].digits[E[+-]digits]
//
// underscore characters may appear zero or more times between
// digits and are ignored by the parser: 500_000
//

const std = @import("std");
const ascii = std.ascii;

fn caseInEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;

    for (a) |_, i| {
        if (ascii.toUpper(a[i]) != ascii.toUpper(b[i])) {
            return false;
        }
    }

    return true;
}

pub const ParseFloatError = error{InvalidCharacter};

//
// Compute 10 to the E-th power.  Examples:  E==1 results in 10.
// E==2 results in 100.  E==50 results in 1.0e50.
//
fn pow10(E_arg: u32) f128 {
    var E = E_arg;
    var x: f128 = 10.0;
    var r: f128 = 1.0;
    while (true) {
        if (E & 1 != 0) r *= x;
        E >>= 1;
        if (E == 0) break;
        x *= x;
    }
    return r;
}

pub fn parseFloat(comptime T: type, str: []const u8) !T {
    if (str.len == 0) return error.InvalidCharacter;

    if (caseInEql(str, "nan")) {
        return std.math.nan(T);
    } else if (caseInEql(str, "inf") or caseInEql(str, "+inf")) {
        return std.math.inf(T);
    } else if (caseInEql(str, "-inf")) {
        return -std.math.inf(T);
    }

    var z: usize = 0; // index into str[]
    // sign * significand * (10 ^ (esign * exponent))
    var sign: i32 = 1; // sign of significand
    var s: i128 = 0; // significand
    var d: i32 = 0; // adjust exponent for shifting decimal point
    var esign: i32 = 1; // sign of exponent
    var e: i32 = 0; // exponent
    var nDigits: i32 = 0;

    // get sign of significand
    if (str[z] == '-') {
        sign = -1;
        z += 1;
    } else if (str[z] == '+') {
        z += 1;
    }

    // copy max significant digits to significand
    while (z < str.len and ((ascii.isDigit(str[z]) and s < ((std.math.maxInt(@TypeOf(s)) - 9) / 10)) or str[z] == '_')) : (z += 1) {
        if (str[z] == '_') continue;
        s = s * 10 + (str[z] - '0');
        nDigits += 1;
    }

    // skip non-significant significand digits
    // (increase exponent by d to shift decimal left)
    while (z < str.len and (ascii.isDigit(str[z]) or str[z] == '_')) : (z += 1) {
        if (str[z] == '_') continue;
        nDigits += 1;
        d += 1;
    }

    do_atof_calc: {
        if (z >= str.len) break :do_atof_calc;

        // if decimal point is present
        if (str[z] == '.') {
            z += 1;

            if ((z < str.len and str[z] == '_') or str[z -| 2] == '_') {
                return error.InvalidCharacter;
            }

            // copy digits from after decimal to significand
            // (decrease exponent by d to shift decimal right)
            while (z < str.len and (ascii.isDigit(str[z]) or str[z] == '_')) : (z += 1) {
                if (str[z] == '_') continue;
                if (s < ((std.math.maxInt(@TypeOf(s)) - 9) / 10)) {
                    s = s * 10 + (str[z] - '0');
                    d -= 1;
                }

                nDigits += 1;
            }
        }
        if (z >= str.len) break :do_atof_calc;

        // if exponent is present
        if (str[z] == 'e' or str[z] == 'E') {
            z += 1;

            if (z >= str.len) return error.InvalidCharacter; // exponent not well formed

            if (str[z -| 2] == '_' or str[z] == '_') {
                return error.InvalidCharacter;
            }

            // get sign of exponent
            if (str[z] == '-') {
                esign = -1;
                z += 1;
            } else if (str[z] == '+') {
                z += 1;
            }

            // copy digits to exponent
            var eValid = false;
            while (z < str.len and (ascii.isDigit(str[z]) or str[z] == '_')) : (z += 1) {
                if (str[z] == '_') continue;
                e = (e *| 10 +| (str[z] - '0'));
                eValid = true;
            }

            if (!eValid) return error.InvalidCharacter;
        }
    } // do_atof_calc block

    if (z != str.len or nDigits == 0) return error.InvalidCharacter;

    // adjust exponent by d, and update sign
    e = (e * esign) + d;
    if (e < 0) {
        esign = -1;
        e *= -1;
    } else {
        esign = 1;
    }

    // Attempt to reduce exponent.
    while (e > 0) {
        if (esign > 0) {
            if (s >= (std.math.maxInt(@TypeOf(s)) / 10)) break;
            s *= 10;
        } else {
            if (@rem(s, 10) != 0) break;
            s = @divTrunc(s, 10);
        }
        e -= 1;
    }

    // adjust the sign of significand
    s = if (sign < 0) -s else s;

    var result: f128 = 0;
    if (s == 0) {
        // In the IEEE 754 standard, zero is signed.
        result = if (sign < 0) -0.0 else 0.0;
    } else if (e == 0) {
        result = @intToFloat(f128, s);
    } else {
        const scale = pow10(@intCast(u32, e));
        if (esign < 0) {
            result = @intToFloat(f128, s) / scale;
        } else {
            result = @intToFloat(f128, s) * scale;
        }
    }

    return @floatCast(T, result);
}

test "fmt.parseFloat" {
    const testing = std.testing;
    const expect = testing.expect;
    const expectEqual = testing.expectEqual;
    const approxEqAbs = std.math.approxEqAbs;
    const epsilon = 1e-7;

    inline for ([_]type{ f16, f32, f64, f128 }) |T| {
        const Z = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);

        try testing.expectError(error.InvalidCharacter, parseFloat(T, ""));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "   1"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "1   "));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "+"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "-"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "1_.5e2"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "1._5e2"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "1.5_e2"));
        try testing.expectError(error.InvalidCharacter, parseFloat(T, "1.5e_2"));

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

        // 4933 is the smallest magnitude exponent that causes an f128 to go to infinity and zero
        try expectEqual(try parseFloat(T, "1e-4933"), 0);
        try expectEqual(try parseFloat(T, "1e+4933"), std.math.inf(T));

        try expectEqual(@bitCast(Z, try parseFloat(T, "nAn")), @bitCast(Z, std.math.nan(T)));
        try expectEqual(try parseFloat(T, "inF"), std.math.inf(T));
        try expectEqual(try parseFloat(T, "-INF"), -std.math.inf(T));

        try expectEqual(try parseFloat(T, "0.4e0066999999999999999999999999999999999999999999999999999"), std.math.inf(T));
        try expect(approxEqAbs(T, try parseFloat(T, "0_1_2_3_4.7_8_9_0_0_0e0_0_2"), @as(T, 1234.789e2), epsilon));

        if (T != f16) {
            try expect(approxEqAbs(T, try parseFloat(T, "1e-2"), 0.01, epsilon));
            try expect(approxEqAbs(T, try parseFloat(T, "1234e-2"), 12.34, epsilon));

            try expect(approxEqAbs(T, try parseFloat(T, "123142.1"), 123142.1, epsilon));
            try expect(approxEqAbs(T, try parseFloat(T, "-123142.1124"), @as(T, -123142.1124), epsilon));
            try expect(approxEqAbs(T, try parseFloat(T, "0.7062146892655368"), @as(T, 0.7062146892655368), epsilon));
            try expect(approxEqAbs(T, try parseFloat(T, "2.71828182845904523536"), @as(T, 2.718281828459045), epsilon));
        }
    }

    // test rounding behavior
    try expectEqual(@bitCast(u64, try parseFloat(f64, "144115188075855870")), 0x4380000000000000); // exact
    try expectEqual(@bitCast(u64, try parseFloat(f64, "144115188075855884")), 0x4380000000000000); // round down
    try expectEqual(@bitCast(u64, try parseFloat(f64, "144115188075855885")), 0x4380000000000000); // round half toward zero
    try expectEqual(@bitCast(u64, try parseFloat(f64, "144115188075855886")), 0x4380000000000000); // round down??
    try expectEqual(@bitCast(u64, try parseFloat(f64, "144115188075855889")), 0x4380000000000001); // round up
    try expectEqual(@bitCast(u64, try parseFloat(f64, "144115188075855900")), 0x4380000000000001); // exact

    try expectEqual(@bitCast(u64, try parseFloat(f64, "9007199254740993")), 0x4340000000000000); // rounded down

    // test precision of f128
    try expectEqual(@bitCast(u128, try parseFloat(f128, "9007199254740993")), 0x40340000000000000800000000000000); // exact

    // test range of f128
    // at time of writing (Mar 2021), zig prints f128 values larger than f64 as "inf",
    // so I'm not 100% sure this hex literal is the corrent parse of 1e4930
    try expectEqual(@bitCast(u128, try parseFloat(f128, "1e4930")), 0x7ff8136c69ce8adff4397b050cae44c7);
}

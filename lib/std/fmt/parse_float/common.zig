const std = @import("std");

/// A custom N-bit floating point type, representing `f * 2^e`.
/// e is biased, so it be directly shifted into the exponent bits.
/// Negative exponent indicates an invalid result.
pub fn BiasedFp(comptime T: type) type {
    const MantissaT = mantissaType(T);

    return struct {
        const Self = @This();

        /// The significant digits.
        f: MantissaT,
        /// The biased, binary exponent.
        e: i32,

        pub fn zero() Self {
            return .{ .f = 0, .e = 0 };
        }

        pub fn zeroPow2(e: i32) Self {
            return .{ .f = 0, .e = e };
        }

        pub fn inf(comptime FloatT: type) Self {
            return .{ .f = 0, .e = (1 << std.math.floatExponentBits(FloatT)) - 1 };
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.f == other.f and self.e == other.e;
        }

        pub fn toFloat(self: Self, comptime FloatT: type, negative: bool) FloatT {
            var word = self.f;
            word |= @as(MantissaT, @intCast(self.e)) << std.math.floatMantissaBits(FloatT);
            var f = floatFromUnsigned(FloatT, MantissaT, word);
            if (negative) f = -f;
            return f;
        }
    };
}

pub fn floatFromUnsigned(comptime T: type, comptime MantissaT: type, v: MantissaT) T {
    return switch (T) {
        f16 => @as(f16, @bitCast(@as(u16, @truncate(v)))),
        f32 => @as(f32, @bitCast(@as(u32, @truncate(v)))),
        f64 => @as(f64, @bitCast(@as(u64, @truncate(v)))),
        f128 => @as(f128, @bitCast(v)),
        else => unreachable,
    };
}

/// Represents a parsed floating point value as its components.
pub fn Number(comptime T: type) type {
    return struct {
        exponent: i64,
        mantissa: mantissaType(T),
        negative: bool,
        /// More than max_mantissa digits were found during parse
        many_digits: bool,
        /// The number was a hex-float (e.g. 0x1.234p567)
        hex: bool,
    };
}

/// Determine if 8 bytes are all decimal digits.
/// This does not care about the order in which the bytes were loaded.
pub fn isEightDigits(v: u64) bool {
    const a = v +% 0x4646_4646_4646_4646;
    const b = v -% 0x3030_3030_3030_3030;
    return ((a | b) & 0x8080_8080_8080_8080) == 0;
}

pub fn isDigit(c: u8, comptime base: u8) bool {
    std.debug.assert(base == 10 or base == 16);

    return if (base == 10)
        '0' <= c and c <= '9'
    else
        '0' <= c and c <= '9' or 'a' <= c and c <= 'f' or 'A' <= c and c <= 'F';
}

/// Returns the underlying storage type used for the mantissa of floating-point type.
/// The output unsigned type must have at least as many bits as the input floating-point type.
pub fn mantissaType(comptime T: type) type {
    return switch (T) {
        f16, f32, f64 => u64,
        f128 => u128,
        else => unreachable,
    };
}

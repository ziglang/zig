const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn FloatRepr(comptime Float: type) type {
    const fractional_bits = floatFractionalBits(Float);
    const exponent_bits = floatExponentBits(Float);
    return packed struct {
        const Repr = @This();

        mantissa: StoredMantissa,
        exponent: BiasedExponent,
        sign: std.math.Sign,

        pub const StoredMantissa = @Type(.{ .int = .{
            .signedness = .unsigned,
            .bits = floatMantissaBits(Float),
        } });
        pub const Mantissa = @Type(.{ .int = .{
            .signedness = .unsigned,
            .bits = 1 + fractional_bits,
        } });
        pub const Exponent = @Type(.{ .int = .{
            .signedness = .signed,
            .bits = exponent_bits,
        } });
        pub const BiasedExponent = enum(@Type(.{ .int = .{
            .signedness = .unsigned,
            .bits = exponent_bits,
        } })) {
            denormal = 0,
            min_normal = 1,
            zero = (1 << (exponent_bits - 1)) - 1,
            max_normal = (1 << exponent_bits) - 2,
            infinite = (1 << exponent_bits) - 1,
            _,

            pub const Int = @typeInfo(BiasedExponent).@"enum".tag_type;

            pub fn unbias(biased: BiasedExponent) Exponent {
                switch (biased) {
                    .denormal => unreachable,
                    else => return @bitCast(@intFromEnum(biased) -% @intFromEnum(BiasedExponent.zero)),
                    .infinite => unreachable,
                }
            }

            pub fn bias(unbiased: Exponent) BiasedExponent {
                return @enumFromInt(@intFromEnum(BiasedExponent.zero) +% @as(Int, @bitCast(unbiased)));
            }
        };

        pub const Normalized = struct {
            fraction: Fraction,
            exponent: Normalized.Exponent,

            pub const Fraction = @Type(.{ .int = .{
                .signedness = .unsigned,
                .bits = fractional_bits,
            } });
            pub const Exponent = @Type(.{ .int = .{
                .signedness = .signed,
                .bits = 1 + exponent_bits,
            } });

            /// This currently truncates denormal values, which needs to be fixed before this can be used to
            /// produce a rounded value.
            pub fn reconstruct(normalized: Normalized, sign: std.math.Sign) Float {
                if (normalized.exponent > BiasedExponent.max_normal.unbias()) return @bitCast(Repr{
                    .mantissa = 0,
                    .exponent = .infinite,
                    .sign = sign,
                });
                const mantissa = @as(Mantissa, 1 << fractional_bits) | normalized.fraction;
                if (normalized.exponent < BiasedExponent.min_normal.unbias()) return @bitCast(Repr{
                    .mantissa = @truncate(std.math.shr(
                        Mantissa,
                        mantissa,
                        BiasedExponent.min_normal.unbias() - normalized.exponent,
                    )),
                    .exponent = .denormal,
                    .sign = sign,
                });
                return @bitCast(Repr{
                    .mantissa = @truncate(mantissa),
                    .exponent = .bias(@intCast(normalized.exponent)),
                    .sign = sign,
                });
            }
        };

        pub const Classified = union(enum) { normalized: Normalized, infinity, nan, invalid };
        fn classify(repr: Repr) Classified {
            return switch (repr.exponent) {
                .denormal => {
                    const mantissa: Mantissa = repr.mantissa;
                    const shift = @clz(mantissa);
                    return .{ .normalized = .{
                        .fraction = @truncate(mantissa << shift),
                        .exponent = @as(Normalized.Exponent, comptime BiasedExponent.min_normal.unbias()) - shift,
                    } };
                },
                else => if (repr.mantissa <= std.math.maxInt(Normalized.Fraction)) .{ .normalized = .{
                    .fraction = @intCast(repr.mantissa),
                    .exponent = repr.exponent.unbias(),
                } } else .invalid,
                .infinite => switch (repr.mantissa) {
                    0 => .infinity,
                    else => .nan,
                },
            };
        }
    };
}

/// Creates a raw "1.0" mantissa for floating point type T. Used to dedupe f80 logic.
inline fn mantissaOne(comptime T: type) comptime_int {
    return if (@typeInfo(T).float.bits == 80) 1 << floatFractionalBits(T) else 0;
}

/// Creates floating point type T from an unbiased exponent and raw mantissa.
inline fn reconstructFloat(comptime T: type, comptime exponent: comptime_int, comptime mantissa: comptime_int) T {
    const TBits = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @bitSizeOf(T) } });
    const biased_exponent = @as(TBits, exponent + floatExponentMax(T));
    return @as(T, @bitCast((biased_exponent << floatMantissaBits(T)) | @as(TBits, mantissa)));
}

/// Returns the number of bits in the exponent of floating point type T.
pub inline fn floatExponentBits(comptime T: type) comptime_int {
    comptime assert(@typeInfo(T) == .float);

    return switch (@typeInfo(T).float.bits) {
        16 => 5,
        32 => 8,
        64 => 11,
        80 => 15,
        128 => 15,
        else => @compileError("unknown floating point type " ++ @typeName(T)),
    };
}

/// Returns the number of bits in the mantissa of floating point type T.
pub inline fn floatMantissaBits(comptime T: type) comptime_int {
    comptime assert(@typeInfo(T) == .float);

    return switch (@typeInfo(T).float.bits) {
        16 => 10,
        32 => 23,
        64 => 52,
        80 => 64,
        128 => 112,
        else => @compileError("unknown floating point type " ++ @typeName(T)),
    };
}

/// Returns the number of fractional bits in the mantissa of floating point type T.
pub inline fn floatFractionalBits(comptime T: type) comptime_int {
    comptime assert(@typeInfo(T) == .float);

    // standard IEEE floats have an implicit 0.m or 1.m integer part
    // f80 is special and has an explicitly stored bit in the MSB
    // this function corresponds to `MANT_DIG - 1' from C
    return switch (@typeInfo(T).float.bits) {
        16 => 10,
        32 => 23,
        64 => 52,
        80 => 63,
        128 => 112,
        else => @compileError("unknown floating point type " ++ @typeName(T)),
    };
}

/// Returns the minimum exponent that can represent
/// a normalised value in floating point type T.
pub inline fn floatExponentMin(comptime T: type) comptime_int {
    return -floatExponentMax(T) + 1;
}

/// Returns the maximum exponent that can represent
/// a normalised value in floating point type T.
pub inline fn floatExponentMax(comptime T: type) comptime_int {
    return (1 << (floatExponentBits(T) - 1)) - 1;
}

/// Returns the smallest subnormal number representable in floating point type T.
pub inline fn floatTrueMin(comptime T: type) T {
    return reconstructFloat(T, floatExponentMin(T) - 1, 1);
}

/// Returns the smallest normal number representable in floating point type T.
pub inline fn floatMin(comptime T: type) T {
    return reconstructFloat(T, floatExponentMin(T), mantissaOne(T));
}

/// Returns the largest normal number representable in floating point type T.
pub inline fn floatMax(comptime T: type) T {
    const all1s_mantissa = (1 << floatMantissaBits(T)) - 1;
    return reconstructFloat(T, floatExponentMax(T), all1s_mantissa);
}

/// Returns the machine epsilon of floating point type T.
pub inline fn floatEps(comptime T: type) T {
    return reconstructFloat(T, -floatFractionalBits(T), mantissaOne(T));
}

/// Returns the local epsilon of floating point type T.
pub inline fn floatEpsAt(comptime T: type, x: T) T {
    switch (@typeInfo(T)) {
        .float => |F| {
            const U: type = @Type(.{ .int = .{ .signedness = .unsigned, .bits = F.bits } });
            const u: U = @bitCast(x);
            const y: T = @bitCast(u ^ 1);
            return @abs(x - y);
        },
        else => @compileError("floatEpsAt only supports floats"),
    }
}

/// Returns the inf value for a floating point `Type`.
pub inline fn inf(comptime Type: type) Type {
    const RuntimeType = switch (Type) {
        else => Type,
        comptime_float => f128, // any float type will do
    };
    return reconstructFloat(RuntimeType, floatExponentMax(RuntimeType) + 1, mantissaOne(RuntimeType));
}

/// Returns the canonical quiet NaN representation for a floating point `Type`.
pub inline fn nan(comptime Type: type) Type {
    const RuntimeType = switch (Type) {
        else => Type,
        comptime_float => f128, // any float type will do
    };
    return reconstructFloat(
        RuntimeType,
        floatExponentMax(RuntimeType) + 1,
        mantissaOne(RuntimeType) | 1 << (floatFractionalBits(RuntimeType) - 1),
    );
}

/// Returns a signalling NaN representation for a floating point `Type`.
///
/// TODO: LLVM is known to miscompile on some architectures to quiet NaN -
///       this is tracked by https://github.com/ziglang/zig/issues/14366
pub inline fn snan(comptime Type: type) Type {
    const RuntimeType = switch (Type) {
        else => Type,
        comptime_float => f128, // any float type will do
    };
    return reconstructFloat(
        RuntimeType,
        floatExponentMax(RuntimeType) + 1,
        mantissaOne(RuntimeType) | 1 << (floatFractionalBits(RuntimeType) - 2),
    );
}

fn floatBits(comptime Type: type) !void {
    // (1 +) for the sign bit, since it is separate from the other bits
    const size = 1 + floatExponentBits(Type) + floatMantissaBits(Type);
    try expect(@bitSizeOf(Type) == size);
    try expect(floatFractionalBits(Type) <= floatMantissaBits(Type));

    // for machine epsilon, assert expmin <= -prec <= expmax
    try expect(floatExponentMin(Type) <= -floatFractionalBits(Type));
    try expect(-floatFractionalBits(Type) <= floatExponentMax(Type));
}
test floatBits {
    try floatBits(f16);
    try floatBits(f32);
    try floatBits(f64);
    try floatBits(f80);
    try floatBits(f128);
    try floatBits(c_longdouble);
}

test inf {
    const inf_u16: u16 = 0x7C00;
    const inf_u32: u32 = 0x7F800000;
    const inf_u64: u64 = 0x7FF0000000000000;
    const inf_u80: u80 = 0x7FFF8000000000000000;
    const inf_u128: u128 = 0x7FFF0000000000000000000000000000;
    try expectEqual(inf_u16, @as(u16, @bitCast(inf(f16))));
    try expectEqual(inf_u32, @as(u32, @bitCast(inf(f32))));
    try expectEqual(inf_u64, @as(u64, @bitCast(inf(f64))));
    try expectEqual(inf_u80, @as(u80, @bitCast(inf(f80))));
    try expectEqual(inf_u128, @as(u128, @bitCast(inf(f128))));
}

test nan {
    const qnan_u16: u16 = 0x7E00;
    const qnan_u32: u32 = 0x7FC00000;
    const qnan_u64: u64 = 0x7FF8000000000000;
    const qnan_u80: u80 = 0x7FFFC000000000000000;
    const qnan_u128: u128 = 0x7FFF8000000000000000000000000000;
    try expectEqual(qnan_u16, @as(u16, @bitCast(nan(f16))));
    try expectEqual(qnan_u32, @as(u32, @bitCast(nan(f32))));
    try expectEqual(qnan_u64, @as(u64, @bitCast(nan(f64))));
    try expectEqual(qnan_u80, @as(u80, @bitCast(nan(f80))));
    try expectEqual(qnan_u128, @as(u128, @bitCast(nan(f128))));
}

test snan {
    const snan_u16: u16 = 0x7D00;
    const snan_u32: u32 = 0x7FA00000;
    const snan_u64: u64 = 0x7FF4000000000000;
    const snan_u80: u80 = 0x7FFFA000000000000000;
    const snan_u128: u128 = 0x7FFF4000000000000000000000000000;
    try expectEqual(snan_u16, @as(u16, @bitCast(snan(f16))));
    try expectEqual(snan_u32, @as(u32, @bitCast(snan(f32))));
    try expectEqual(snan_u64, @as(u64, @bitCast(snan(f64))));
    try expectEqual(snan_u80, @as(u80, @bitCast(snan(f80))));
    try expectEqual(snan_u128, @as(u128, @bitCast(snan(f128))));
}

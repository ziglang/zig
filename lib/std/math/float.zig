const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Creates a raw "1.0" mantissa for floating point type T. Used to dedupe f80 logic.
inline fn mantissaOne(comptime T: type) comptime_int {
    return if (@typeInfo(T).Float.bits == 80) 1 << floatFractionalBits(T) else 0;
}

/// Creates floating point type T from an unbiased exponent and raw mantissa.
inline fn reconstructFloat(comptime T: type, comptime exponent: comptime_int, comptime mantissa: comptime_int) T {
    const TBits = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = @bitSizeOf(T) } });
    const biased_exponent = @as(TBits, exponent + floatExponentMax(T));
    return @as(T, @bitCast((biased_exponent << floatMantissaBits(T)) | @as(TBits, mantissa)));
}

/// Returns the number of bits in the exponent of floating point type T.
pub inline fn floatExponentBits(comptime T: type) comptime_int {
    comptime assert(@typeInfo(T) == .Float);

    return switch (@typeInfo(T).Float.bits) {
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
    comptime assert(@typeInfo(T) == .Float);

    return switch (@typeInfo(T).Float.bits) {
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
    comptime assert(@typeInfo(T) == .Float);

    // standard IEEE floats have an implicit 0.m or 1.m integer part
    // f80 is special and has an explicitly stored bit in the MSB
    // this function corresponds to `MANT_DIG - 1' from C
    return switch (@typeInfo(T).Float.bits) {
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

/// Returns the value inf for floating point type T.
pub inline fn inf(comptime T: type) T {
    return reconstructFloat(T, floatExponentMax(T) + 1, mantissaOne(T));
}

/// Returns the canonical quiet NaN representation for floating point type T.
pub inline fn nan(comptime T: type) T {
    return reconstructFloat(
        T,
        floatExponentMax(T) + 1,
        mantissaOne(T) | 1 << (floatFractionalBits(T) - 1),
    );
}

/// Returns a signalling NaN representation for floating point type T.
///
/// TODO: LLVM is known to miscompile on some architectures to quiet NaN -
///       this is tracked by https://github.com/ziglang/zig/issues/14366
pub inline fn snan(comptime T: type) T {
    return reconstructFloat(
        T,
        floatExponentMax(T) + 1,
        mantissaOne(T) | 1 << (floatFractionalBits(T) - 2),
    );
}

test "float bits" {
    inline for ([_]type{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        // (1 +) for the sign bit, since it is separate from the other bits
        const size = 1 + floatExponentBits(T) + floatMantissaBits(T);
        try expect(@bitSizeOf(T) == size);

        // for machine epsilon, assert expmin <= -prec <= expmax
        try expect(floatExponentMin(T) <= -floatFractionalBits(T));
        try expect(-floatFractionalBits(T) <= floatExponentMax(T));
    }
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
    // TODO: https://github.com/ziglang/zig/issues/14366
    if (builtin.zig_backend == .stage2_llvm and comptime builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;

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

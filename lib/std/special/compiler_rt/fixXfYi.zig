const std = @import("std");
const math = std.math;
const Log2Int = math.Log2Int;
const is_test = @import("builtin").is_test;

pub inline fn fixXfYi(comptime I: type, a: anytype) I {
    @setRuntimeSafety(is_test);

    const F = @TypeOf(a);
    const float_bits = @typeInfo(F).Float.bits;
    const int_bits = @typeInfo(I).Int.bits;
    const rep_t = std.meta.Int(.unsigned, float_bits);
    const sig_bits = math.floatMantissaBits(F);
    const exp_bits = math.floatExponentBits(F);
    const fractional_sig_bits = math.floatMantissaDigits(F) - 1;

    const implicit_bit = if (F != f80) (@as(rep_t, 1) << sig_bits) else 0;
    const max_exp = (1 << (exp_bits - 1));
    const exp_bias = max_exp - 1;
    const sig_mask = (@as(rep_t, 1) << sig_bits) - 1;

    // Break a into sign, exponent, significand
    const a_rep: rep_t = @bitCast(rep_t, a);
    const negative = (a_rep >> (float_bits - 1)) != 0;
    const exponent = @intCast(i32, (a_rep << 1) >> (sig_bits + 1)) - exp_bias;
    const significand: rep_t = (a_rep & sig_mask) | implicit_bit;

    // If the exponent is negative, the result rounds to zero.
    if (exponent < 0) return 0;

    // If the value is too large for the integer type, saturate.
    switch (@typeInfo(I).Int.signedness) {
        .unsigned => {
            if (negative) return 0;
            if (@intCast(c_uint, exponent) >= @minimum(int_bits, max_exp)) return math.maxInt(I);
        },
        .signed => if (@intCast(c_uint, exponent) >= @minimum(int_bits - 1, max_exp)) {
            return if (negative) math.minInt(I) else math.maxInt(I);
        },
    }

    // If 0 <= exponent < sig_bits, right shift to get the result.
    // Otherwise, shift left.
    var result: I = undefined;
    if (exponent < fractional_sig_bits) {
        result = @intCast(I, significand >> @intCast(Log2Int(rep_t), fractional_sig_bits - exponent));
    } else {
        result = @intCast(I, significand) << @intCast(Log2Int(I), exponent - fractional_sig_bits);
    }

    if ((@typeInfo(I).Int.signedness == .signed) and negative)
        return ~result +% 1;
    return result;
}

// Conversion from f16

pub fn __fixhfsi(a: f16) callconv(.C) i32 {
    return fixXfYi(i32, a);
}

pub fn __fixunshfsi(a: f16) callconv(.C) u32 {
    return fixXfYi(u32, a);
}

pub fn __fixhfdi(a: f16) callconv(.C) i64 {
    return fixXfYi(i64, a);
}

pub fn __fixunshfdi(a: f16) callconv(.C) u64 {
    return fixXfYi(u64, a);
}

pub fn __fixhfti(a: f16) callconv(.C) i128 {
    return fixXfYi(i128, a);
}

pub fn __fixunshfti(a: f16) callconv(.C) u128 {
    return fixXfYi(u128, a);
}

// Conversion from f32

pub fn __fixsfsi(a: f32) callconv(.C) i32 {
    return fixXfYi(i32, a);
}

pub fn __fixunssfsi(a: f32) callconv(.C) u32 {
    return fixXfYi(u32, a);
}

pub fn __fixsfdi(a: f32) callconv(.C) i64 {
    return fixXfYi(i64, a);
}

pub fn __fixunssfdi(a: f32) callconv(.C) u64 {
    return fixXfYi(u64, a);
}

pub fn __fixsfti(a: f32) callconv(.C) i128 {
    return fixXfYi(i128, a);
}

pub fn __fixunssfti(a: f32) callconv(.C) u128 {
    return fixXfYi(u128, a);
}

// Conversion from f64

pub fn __fixdfsi(a: f64) callconv(.C) i32 {
    return fixXfYi(i32, a);
}

pub fn __fixunsdfsi(a: f64) callconv(.C) u32 {
    return fixXfYi(u32, a);
}

pub fn __fixdfdi(a: f64) callconv(.C) i64 {
    return fixXfYi(i64, a);
}

pub fn __fixunsdfdi(a: f64) callconv(.C) u64 {
    return fixXfYi(u64, a);
}

pub fn __fixdfti(a: f64) callconv(.C) i128 {
    return fixXfYi(i128, a);
}

pub fn __fixunsdfti(a: f64) callconv(.C) u128 {
    return fixXfYi(u128, a);
}

// Conversion from f80

pub fn __fixxfsi(a: f80) callconv(.C) i32 {
    return fixXfYi(i32, a);
}

pub fn __fixunsxfsi(a: f80) callconv(.C) u32 {
    return fixXfYi(u32, a);
}

pub fn __fixxfdi(a: f80) callconv(.C) i64 {
    return fixXfYi(i64, a);
}

pub fn __fixunsxfdi(a: f80) callconv(.C) u64 {
    return fixXfYi(u64, a);
}

pub fn __fixxfti(a: f80) callconv(.C) i128 {
    return fixXfYi(i128, a);
}

pub fn __fixunsxfti(a: f80) callconv(.C) u128 {
    return fixXfYi(u128, a);
}

// Conversion from f128

pub fn __fixtfsi(a: f128) callconv(.C) i32 {
    return fixXfYi(i32, a);
}

pub fn __fixunstfsi(a: f128) callconv(.C) u32 {
    return fixXfYi(u32, a);
}

pub fn __fixtfdi(a: f128) callconv(.C) i64 {
    return fixXfYi(i64, a);
}

pub fn __fixunstfdi(a: f128) callconv(.C) u64 {
    return fixXfYi(u64, a);
}

pub fn __fixtfti(a: f128) callconv(.C) i128 {
    return fixXfYi(i128, a);
}

pub fn __fixunstfti(a: f128) callconv(.C) u128 {
    return fixXfYi(u128, a);
}

// Conversion from f32

pub fn __aeabi_f2iz(a: f32) callconv(.AAPCS) i32 {
    return fixXfYi(i32, a);
}

pub fn __aeabi_f2uiz(a: f32) callconv(.AAPCS) u32 {
    return fixXfYi(u32, a);
}

pub fn __aeabi_f2lz(a: f32) callconv(.AAPCS) i64 {
    return fixXfYi(i64, a);
}

pub fn __aeabi_f2ulz(a: f32) callconv(.AAPCS) u64 {
    return fixXfYi(u64, a);
}

// Conversion from f64

pub fn __aeabi_d2iz(a: f64) callconv(.AAPCS) i32 {
    return fixXfYi(i32, a);
}

pub fn __aeabi_d2uiz(a: f64) callconv(.AAPCS) u32 {
    return fixXfYi(u32, a);
}

pub fn __aeabi_d2lz(a: f64) callconv(.AAPCS) i64 {
    return fixXfYi(i64, a);
}

pub fn __aeabi_d2ulz(a: f64) callconv(.AAPCS) u64 {
    return fixXfYi(u64, a);
}

test {
    _ = @import("fixXfYi_test.zig");
}

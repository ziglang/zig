const std = @import("std");

pub fn __fabsh(a: f16) callconv(.C) f16 {
    return generic_fabs(a);
}

pub fn fabsf(a: f32) callconv(.C) f32 {
    return generic_fabs(a);
}

pub fn fabs(a: f64) callconv(.C) f64 {
    return generic_fabs(a);
}

pub fn __fabsx(a: f80) callconv(.C) f80 {
    return generic_fabs(a);
}

pub fn fabsq(a: f128) callconv(.C) f128 {
    return generic_fabs(a);
}

inline fn generic_fabs(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    const TBits = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
    const float_bits = @bitCast(TBits, x);
    const remove_sign = ~@as(TBits, 0) >> 1;
    return @bitCast(T, float_bits & remove_sign);
}

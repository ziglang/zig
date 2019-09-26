const std = @import("std");

pub extern fn __negsf2(a: f32) f32 {
    return negXf2(f32, a);
}

pub extern fn __negdf2(a: f64) f64 {
    return negXf2(f64, a);
}

fn negXf2(comptime T: type, a: T) T {
    const Z = @IntType(false, T.bit_count);

    const typeWidth = T.bit_count;
    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);

    const signBit = (Z(1) << (significandBits + exponentBits));

    return @bitCast(T, @bitCast(Z, a) ^ signBit);
}

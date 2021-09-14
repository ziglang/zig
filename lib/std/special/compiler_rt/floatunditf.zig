const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");

pub fn __floatunditf(a: u64) callconv(.C) f128 {
    @setRuntimeSafety(is_test);

    if (a == 0) {
        return 0;
    }

    const mantissa_bits = std.math.floatMantissaBits(f128);
    const exponent_bits = std.math.floatExponentBits(f128);
    const exponent_bias = (1 << (exponent_bits - 1)) - 1;
    const implicit_bit = 1 << mantissa_bits;

    const exp: u128 = (64 - 1) - @clz(u64, a);
    const shift: u7 = mantissa_bits - @intCast(u7, exp);

    var result: u128 = (@intCast(u128, a) << shift) ^ implicit_bit;
    result += (exp + exponent_bias) << mantissa_bits;

    return @bitCast(f128, result);
}

test {
    _ = @import("floatunditf_test.zig");
}

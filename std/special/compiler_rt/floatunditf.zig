const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");

pub extern fn __floatunditf(a: u128) f128 {
    @setRuntimeSafety(is_test);

    if (a == 0) {
        return 0;
    }

    const mantissa_bits = std.math.floatMantissaBits(f128);
    const exponent_bits = std.math.floatExponentBits(f128);
    const exponent_bias = (1 << (exponent_bits - 1)) - 1;
    const implicit_bit = 1 << mantissa_bits;

    const exp = (u128.bit_count - 1) - @clz(a);
    const shift = mantissa_bits - @intCast(u7, exp);

    var result: u128 align(16) = (a << shift) ^ implicit_bit;
    result += (@intCast(u128, exp) + exponent_bias) << mantissa_bits;

    return @bitCast(f128, result);
}

test "import floatunditf" {
    _ = @import("floatunditf_test.zig");
}

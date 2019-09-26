const builtin = @import("builtin");
const std = @import("std");
const maxInt = std.math.maxInt;

const implicitBit = u64(1) << 52;

pub extern fn __floatunsidf(arg: u32) f64 {
    @setRuntimeSafety(builtin.is_test);

    if (arg == 0) return 0.0;

    // The exponent is the width of abs(a)
    const exp = u64(31) - @clz(u32, arg);
    // Shift a into the significand field and clear the implicit bit
    const shift = @intCast(u6, 52 - exp);
    const mant = u64(arg) << shift ^ implicitBit;

    return @bitCast(f64, mant | (exp + 1023) << 52);
}

fn test_one_floatunsidf(a: u32, expected: u64) void {
    const r = __floatunsidf(a);
    std.testing.expect(@bitCast(u64, r) == expected);
}

test "floatsidf" {
    // Test the produced bit pattern
    test_one_floatunsidf(0, 0x0000000000000000);
    test_one_floatunsidf(1, 0x3ff0000000000000);
    test_one_floatunsidf(0x7FFFFFFF, 0x41dfffffffc00000);
    test_one_floatunsidf(@intCast(u32, 0x80000000), 0x41e0000000000000);
    test_one_floatunsidf(@intCast(u32, 0xFFFFFFFF), 0x41efffffffe00000);
}

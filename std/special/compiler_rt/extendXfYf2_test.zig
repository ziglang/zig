const __extenddftf2 = @import("extendXfYf2.zig").__extenddftf2;
const __extendsftf2 = @import("extendXfYf2.zig").__extendsftf2;
const assert = @import("std").debug.assert;

fn test__extenddftf2(a: f64, expectedHi: u64, expectedLo: u64) void {
    const x = __extenddftf2(a);

    const rep = @bitCast(u128, x);
    const hi = @intCast(u64, rep >> 64);
    const lo = @truncate(u64, rep);

    if (hi == expectedHi and lo == expectedLo)
        return;

    // test other possible NaN representation(signal NaN)
    if (expectedHi == 0x7fff800000000000 and expectedLo == 0x0) {
        if ((hi & 0x7fff000000000000) == 0x7fff000000000000 and
            ((hi & 0xffffffffffff) > 0 or lo > 0))
        {
            return;
        }
    }

    @panic("__extenddftf2 test failure");
}

fn test__extendsftf2(a: f32, expectedHi: u64, expectedLo: u64) void {
    const x = __extendsftf2(a);

    const rep = @bitCast(u128, x);
    const hi = @intCast(u64, rep >> 64);
    const lo = @truncate(u64, rep);

    if (hi == expectedHi and lo == expectedLo)
        return;

    // test other possible NaN representation(signal NaN)
    if (expectedHi == 0x7fff800000000000 and expectedLo == 0x0) {
        if ((hi & 0x7fff000000000000) == 0x7fff000000000000 and
            ((hi & 0xffffffffffff) > 0 or lo > 0))
        {
            return;
        }
    }

    @panic("__extendsftf2 test failure");
}

test "extenddftf2" {
    // qNaN
    test__extenddftf2(makeQNaN64(), 0x7fff800000000000, 0x0);

    // NaN
    test__extenddftf2(makeNaN64(0x7100000000000), 0x7fff710000000000, 0x0);

    // inf
    test__extenddftf2(makeInf64(), 0x7fff000000000000, 0x0);

    // zero
    test__extenddftf2(0.0, 0x0, 0x0);

    test__extenddftf2(0x1.23456789abcdefp+5, 0x400423456789abcd, 0xf000000000000000);

    test__extenddftf2(0x1.edcba987654321fp-9, 0x3ff6edcba9876543, 0x2000000000000000);

    test__extenddftf2(0x1.23456789abcdefp+45, 0x402c23456789abcd, 0xf000000000000000);

    test__extenddftf2(0x1.edcba987654321fp-45, 0x3fd2edcba9876543, 0x2000000000000000);
}

test "extendsftf2" {
    // qNaN
    test__extendsftf2(makeQNaN32(), 0x7fff800000000000, 0x0);
    // NaN
    test__extendsftf2(makeNaN32(0x410000), 0x7fff820000000000, 0x0);
    // inf
    test__extendsftf2(makeInf32(), 0x7fff000000000000, 0x0);
    // zero
    test__extendsftf2(0.0, 0x0, 0x0);
    test__extendsftf2(0x1.23456p+5, 0x4004234560000000, 0x0);
    test__extendsftf2(0x1.edcbap-9, 0x3ff6edcba0000000, 0x0);
    test__extendsftf2(0x1.23456p+45, 0x402c234560000000, 0x0);
    test__extendsftf2(0x1.edcbap-45, 0x3fd2edcba0000000, 0x0);
}

fn makeQNaN64() f64 {
    return @bitCast(f64, u64(0x7ff8000000000000));
}

fn makeInf64() f64 {
    return @bitCast(f64, u64(0x7ff0000000000000));
}

fn makeNaN64(rand: u64) f64 {
    return @bitCast(f64, 0x7ff0000000000000 | (rand & 0xfffffffffffff));
}

fn makeQNaN32() f32 {
    return @bitCast(f32, u32(0x7fc00000));
}

fn makeNaN32(rand: u32) f32 {
    return @bitCast(f32, 0x7f800000 | (rand & 0x7fffff));
}

fn makeInf32() f32 {
    return @bitCast(f32, u32(0x7f800000));
}

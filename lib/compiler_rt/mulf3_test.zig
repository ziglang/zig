// Ported from:
//
// https://github.com/llvm/llvm-project/blob/2ffb1b0413efa9a24eb3c49e710e36f92e2cb50b/compiler-rt/test/builtins/Unit/multf3_test.c

const std = @import("std");
const math = std.math;
const qnan128: f128 = @bitCast(@as(u128, 0x7fff800000000000) << 64);
const inf128: f128 = @bitCast(@as(u128, 0x7fff000000000000) << 64);

const __multf3 = @import("multf3.zig").__multf3;
const __mulxf3 = @import("mulxf3.zig").__mulxf3;
const __muldf3 = @import("muldf3.zig").__muldf3;
const __mulsf3 = @import("mulsf3.zig").__mulsf3;

// return true if equal
// use two 64-bit integers instead of one 128-bit integer
// because 128-bit integer constant can't be assigned directly
fn compareResultLD(result: f128, expectedHi: u64, expectedLo: u64) bool {
    const rep: u128 = @bitCast(result);
    const hi: u64 = @intCast(rep >> 64);
    const lo: u64 = @truncate(rep);

    if (hi == expectedHi and lo == expectedLo) {
        return true;
    }
    // test other possible NaN representation(signal NaN)
    if (expectedHi == 0x7fff800000000000 and expectedLo == 0x0) {
        if ((hi & 0x7fff000000000000) == 0x7fff000000000000 and
            ((hi & 0xffffffffffff) > 0 or lo > 0))
        {
            return true;
        }
    }
    return false;
}

fn test__multf3(a: f128, b: f128, expected_hi: u64, expected_lo: u64) !void {
    const x = __multf3(a, b);

    if (compareResultLD(x, expected_hi, expected_lo))
        return;

    @panic("__multf3 test failure");
}

fn makeNaN128(rand: u64) f128 {
    const int_result = @as(u128, 0x7fff000000000000 | (rand & 0xffffffffffff)) << 64;
    return @bitCast(int_result);
}
test "multf3" {
    // qNaN * any = qNaN
    try test__multf3(qnan128, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // NaN * any = NaN
    const a = makeNaN128(0x800030000000);
    try test__multf3(a, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);
    // inf * any = inf
    try test__multf3(inf128, 0x1.23456789abcdefp+5, 0x7fff000000000000, 0x0);

    // any * any
    try test__multf3(
        @as(f128, @bitCast(@as(u128, 0x40042eab345678439abcdefea5678234))),
        @as(f128, @bitCast(@as(u128, 0x3ffeedcb34a235253948765432134675))),
        0x400423e7f9e3c9fc,
        0xd906c2c2a85777c4,
    );

    try test__multf3(
        @as(f128, @bitCast(@as(u128, 0x3fcd353e45674d89abacc3a2ebf3ff50))),
        @as(f128, @bitCast(@as(u128, 0x3ff6ed8764648369535adf4be3214568))),
        0x3fc52a163c6223fc,
        0xc94c4bf0430768b4,
    );

    try test__multf3(
        0x1.234425696abcad34a35eeffefdcbap+456,
        0x451.ed98d76e5d46e5f24323dff21ffp+600,
        0x44293a91de5e0e94,
        0xe8ed17cc2cdf64ac,
    );

    try test__multf3(
        @as(f128, @bitCast(@as(u128, 0x3f154356473c82a9fabf2d22ace345df))),
        @as(f128, @bitCast(@as(u128, 0x3e38eda98765476743ab21da23d45679))),
        0x3d4f37c1a3137cae,
        0xfc6807048bc2836a,
    );

    try test__multf3(0x1.23456734245345p-10000, 0x1.edcba524498724p-6497, 0x0, 0x0);

    // Denormal operands.
    try test__multf3(
        0x0.0000000000000000000000000001p-16382,
        0x1p16383,
        0x3f90000000000000,
        0x0,
    );
    try test__multf3(
        0x1p16383,
        0x0.0000000000000000000000000001p-16382,
        0x3f90000000000000,
        0x0,
    );

    try test__multf3(0x1.0000_0000_0000_0000_0000_0000_0001p+0, 0x1.8p+5, 0x4004_8000_0000_0000, 0x0000_0000_0000_0002);
    try test__multf3(0x1.0000_0000_0000_0000_0000_0000_0002p+0, 0x1.8p+5, 0x4004_8000_0000_0000, 0x0000_0000_0000_0003);
    try test__multf3(2.0, math.floatTrueMin(f128), 0x0000_0000_0000_0000, 0x0000_0000_0000_0002);
}

const qnan80: f80 = @bitCast(@as(u80, @bitCast(math.nan(f80))) | (1 << (math.floatFractionalBits(f80) - 1)));

fn test__mulxf3(a: f80, b: f80, expected: u80) !void {
    const x = __mulxf3(a, b);
    const rep: u80 = @bitCast(x);

    if (rep == expected)
        return;

    if (math.isNan(@as(f80, @bitCast(expected))) and math.isNan(x))
        return; // We don't currently test NaN payload propagation

    return error.TestFailed;
}

test "mulxf3" {
    // NaN * any = NaN
    try test__mulxf3(qnan80, 0x1.23456789abcdefp+5, @as(u80, @bitCast(qnan80)));
    try test__mulxf3(@as(f80, @bitCast(@as(u80, 0x7fff_8000_8000_3000_0000))), 0x1.23456789abcdefp+5, @as(u80, @bitCast(qnan80)));

    // any * NaN = NaN
    try test__mulxf3(0x1.23456789abcdefp+5, qnan80, @as(u80, @bitCast(qnan80)));
    try test__mulxf3(0x1.23456789abcdefp+5, @as(f80, @bitCast(@as(u80, 0x7fff_8000_8000_3000_0000))), @as(u80, @bitCast(qnan80)));

    // NaN * inf = NaN
    try test__mulxf3(qnan80, math.inf(f80), @as(u80, @bitCast(qnan80)));

    // inf * NaN = NaN
    try test__mulxf3(math.inf(f80), qnan80, @as(u80, @bitCast(qnan80)));

    // inf * inf = inf
    try test__mulxf3(math.inf(f80), math.inf(f80), @as(u80, @bitCast(math.inf(f80))));

    // inf * -inf = -inf
    try test__mulxf3(math.inf(f80), -math.inf(f80), @as(u80, @bitCast(-math.inf(f80))));

    // -inf + inf = -inf
    try test__mulxf3(-math.inf(f80), math.inf(f80), @as(u80, @bitCast(-math.inf(f80))));

    // inf * any = inf
    try test__mulxf3(math.inf(f80), 0x1.2335653452436234723489432abcdefp+5, @as(u80, @bitCast(math.inf(f80))));

    // any * inf = inf
    try test__mulxf3(0x1.2335653452436234723489432abcdefp+5, math.inf(f80), @as(u80, @bitCast(math.inf(f80))));

    // any * any
    try test__mulxf3(0x1.0p+0, 0x1.dcba987654321p+5, 0x4004_ee5d_4c3b_2a19_0800);
    try test__mulxf3(0x1.0000_0000_0000_0004p+0, 0x1.8p+5, 0x4004_C000_0000_0000_0003); // exact

    try test__mulxf3(0x1.0000_0000_0000_0002p+0, 0x1.0p+5, 0x4004_8000_0000_0000_0001); // exact
    try test__mulxf3(0x1.0000_0000_0000_0002p+0, 0x1.7ffep+5, 0x4004_BFFF_0000_0000_0001); // round down
    try test__mulxf3(0x1.0000_0000_0000_0002p+0, 0x1.8p+5, 0x4004_C000_0000_0000_0002); // round up to even
    try test__mulxf3(0x1.0000_0000_0000_0002p+0, 0x1.8002p+5, 0x4004_C001_0000_0000_0002); // round up
    try test__mulxf3(0x1.0000_0000_0000_0002p+0, 0x1.0p+6, 0x4005_8000_0000_0000_0001); // exact

    try test__mulxf3(0x1.0000_0001p+0, 0x1.0000_0001p+0, 0x3FFF_8000_0001_0000_0000); // round down to even
    try test__mulxf3(0x1.0000_0001p+0, 0x1.0000_0001_0002p+0, 0x3FFF_8000_0001_0001_0001); // round up
    try test__mulxf3(0x0.8000_0000_0000_0000p-16382, 2.0, 0x0001_8000_0000_0000_0000); // denormal -> normal
    try test__mulxf3(0x0.7fff_ffff_ffff_fffep-16382, 0x2.0000_0000_0000_0008p0, 0x0001_8000_0000_0000_0000); // denormal -> normal
    try test__mulxf3(0x0.7fff_ffff_ffff_fffep-16382, 0x1.0000_0000_0000_0000p0, 0x0000_3FFF_FFFF_FFFF_FFFF); // denormal -> denormal
}

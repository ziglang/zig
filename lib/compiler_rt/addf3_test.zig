// Ported from:
//
// https://github.com/llvm/llvm-project/blob/02d85149a05cb1f6dc49f0ba7a2ceca53718ae17/compiler-rt/test/builtins/Unit/addtf3_test.c
// https://github.com/llvm/llvm-project/blob/02d85149a05cb1f6dc49f0ba7a2ceca53718ae17/compiler-rt/test/builtins/Unit/subtf3_test.c

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const qnan128: f128 = @bitCast(@as(u128, 0x7fff800000000000) << 64);

const __addtf3 = @import("addtf3.zig").__addtf3;
const __addxf3 = @import("addxf3.zig").__addxf3;
const __subtf3 = @import("subtf3.zig").__subtf3;

fn test__addtf3(a: f128, b: f128, expected_hi: u64, expected_lo: u64) !void {
    const x = __addtf3(a, b);

    const rep: u128 = @bitCast(x);
    const hi: u64 = @intCast(rep >> 64);
    const lo: u64 = @truncate(rep);

    if (hi == expected_hi and lo == expected_lo) {
        return;
    }
    // test other possible NaN representation (signal NaN)
    else if (expected_hi == 0x7fff800000000000 and expected_lo == 0x0) {
        if ((hi & 0x7fff000000000000) == 0x7fff000000000000 and
            ((hi & 0xffffffffffff) > 0 or lo > 0))
        {
            return;
        }
    }

    return error.TestFailed;
}

test "addtf3" {
    try test__addtf3(qnan128, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // NaN + any = NaN
    try test__addtf3(@as(f128, @bitCast((@as(u128, 0x7fff000000000000) << 64) | @as(u128, 0x800030000000))), 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // inf + inf = inf
    try test__addtf3(math.inf(f128), math.inf(f128), 0x7fff000000000000, 0x0);

    // inf + any = inf
    try test__addtf3(math.inf(f128), 0x1.2335653452436234723489432abcdefp+5, 0x7fff000000000000, 0x0);

    // any + any
    try test__addtf3(0x1.23456734245345543849abcdefp+5, 0x1.edcba52449872455634654321fp-1, 0x40042afc95c8b579, 0x61e58dd6c51eb77c);
    try test__addtf3(0x1.edcba52449872455634654321fp-1, 0x1.23456734245345543849abcdefp+5, 0x40042afc95c8b579, 0x61e58dd6c51eb77c);
}

fn test__subtf3(a: f128, b: f128, expected_hi: u64, expected_lo: u64) !void {
    const x = __subtf3(a, b);

    const rep: u128 = @bitCast(x);
    const hi: u64 = @intCast(rep >> 64);
    const lo: u64 = @truncate(rep);

    if (hi == expected_hi and lo == expected_lo) {
        return;
    }
    // test other possible NaN representation (signal NaN)
    else if (expected_hi == 0x7fff800000000000 and expected_lo == 0x0) {
        if ((hi & 0x7fff000000000000) == 0x7fff000000000000 and
            ((hi & 0xffffffffffff) > 0 or lo > 0))
        {
            return;
        }
    }

    return error.TestFailed;
}

test "subtf3" {
    // qNaN - any = qNaN
    try test__subtf3(qnan128, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // NaN + any = NaN
    try test__subtf3(@as(f128, @bitCast((@as(u128, 0x7fff000000000000) << 64) | @as(u128, 0x800030000000))), 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // inf - any = inf
    try test__subtf3(math.inf(f128), 0x1.23456789abcdefp+5, 0x7fff000000000000, 0x0);

    // any + any
    try test__subtf3(0x1.234567829a3bcdef5678ade36734p+5, 0x1.ee9d7c52354a6936ab8d7654321fp-1, 0x40041b8af1915166, 0xa44a7bca780a166c);
    try test__subtf3(0x1.ee9d7c52354a6936ab8d7654321fp-1, 0x1.234567829a3bcdef5678ade36734p+5, 0xc0041b8af1915166, 0xa44a7bca780a166c);
}

const qnan80: f80 = @bitCast(@as(u80, @bitCast(math.nan(f80))) | (1 << (math.floatFractionalBits(f80) - 1)));

fn test__addxf3(a: f80, b: f80, expected: u80) !void {
    const x = __addxf3(a, b);
    const rep: u80 = @bitCast(x);

    if (rep == expected)
        return;

    if (math.isNan(@as(f80, @bitCast(expected))) and math.isNan(x))
        return; // We don't currently test NaN payload propagation

    return error.TestFailed;
}

test "addxf3" {
    // NaN + any = NaN
    try test__addxf3(qnan80, 0x1.23456789abcdefp+5, @as(u80, @bitCast(qnan80)));
    try test__addxf3(@as(f80, @bitCast(@as(u80, 0x7fff_8000_8000_3000_0000))), 0x1.23456789abcdefp+5, @as(u80, @bitCast(qnan80)));

    // any + NaN = NaN
    try test__addxf3(0x1.23456789abcdefp+5, qnan80, @as(u80, @bitCast(qnan80)));
    try test__addxf3(0x1.23456789abcdefp+5, @as(f80, @bitCast(@as(u80, 0x7fff_8000_8000_3000_0000))), @as(u80, @bitCast(qnan80)));

    // NaN + inf = NaN
    try test__addxf3(qnan80, math.inf(f80), @as(u80, @bitCast(qnan80)));

    // inf + NaN = NaN
    try test__addxf3(math.inf(f80), qnan80, @as(u80, @bitCast(qnan80)));

    // inf + inf = inf
    try test__addxf3(math.inf(f80), math.inf(f80), @as(u80, @bitCast(math.inf(f80))));

    // inf + -inf = NaN
    try test__addxf3(math.inf(f80), -math.inf(f80), @as(u80, @bitCast(qnan80)));

    // -inf + inf = NaN
    try test__addxf3(-math.inf(f80), math.inf(f80), @as(u80, @bitCast(qnan80)));

    // inf + any = inf
    try test__addxf3(math.inf(f80), 0x1.2335653452436234723489432abcdefp+5, @as(u80, @bitCast(math.inf(f80))));

    // any + inf = inf
    try test__addxf3(0x1.2335653452436234723489432abcdefp+5, math.inf(f80), @as(u80, @bitCast(math.inf(f80))));

    // any + any
    try test__addxf3(0x1.23456789abcdp+5, 0x1.dcba987654321p+5, 0x4005_BFFFFFFFFFFFC400);
    try test__addxf3(0x1.23456734245345543849abcdefp+5, 0x1.edcba52449872455634654321fp-1, 0x4004_957E_4AE4_5ABC_B0F3);
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x1.0p-63, 0x3FFF_FFFFFFFFFFFFFFFF); // exact
    try test__addxf3(0x1.ffff_ffff_ffff_fffep+0, 0x0.0p0, 0x3FFF_FFFFFFFFFFFFFFFF); // exact
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x1.4p-63, 0x3FFF_FFFFFFFFFFFFFFFF); // round down
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x1.8p-63, 0x4000_8000000000000000); // round up to even
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x1.cp-63, 0x4000_8000000000000000); // round up
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x2.0p-63, 0x4000_8000000000000000); // exact
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x2.1p-63, 0x4000_8000000000000000); // round down
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x3.0p-63, 0x4000_8000000000000000); // round down to even
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x3.1p-63, 0x4000_8000000000000001); // round up
    try test__addxf3(0x1.ffff_ffff_ffff_fffcp+0, 0x4.0p-63, 0x4000_8000000000000001); // exact

    try test__addxf3(0x1.0fff_ffff_ffff_fffep+0, 0x1.0p-63, 0x3FFF_8800000000000000); // exact
    try test__addxf3(0x1.0fff_ffff_ffff_fffep+0, 0x1.7p-63, 0x3FFF_8800000000000000); // round down
    try test__addxf3(0x1.0fff_ffff_ffff_fffep+0, 0x1.8p-63, 0x3FFF_8800000000000000); // round down to even
    try test__addxf3(0x1.0fff_ffff_ffff_fffep+0, 0x1.9p-63, 0x3FFF_8800000000000001); // round up
    try test__addxf3(0x1.0fff_ffff_ffff_fffep+0, 0x2.0p-63, 0x3FFF_8800000000000001); // exact
    try test__addxf3(0x0.ffff_ffff_ffff_fffcp-16382, 0x0.0000_0000_0000_0002p-16382, 0x0000_7FFFFFFFFFFFFFFF); // exact
    try test__addxf3(0x0.1fff_ffff_ffff_fffcp-16382, 0x0.0000_0000_0000_0002p-16382, 0x0000_0FFFFFFFFFFFFFFF); // exact
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from:
//
// https://github.com/llvm/llvm-project/blob/02d85149a05cb1f6dc49f0ba7a2ceca53718ae17/compiler-rt/test/builtins/Unit/addtf3_test.c
// https://github.com/llvm/llvm-project/blob/02d85149a05cb1f6dc49f0ba7a2ceca53718ae17/compiler-rt/test/builtins/Unit/subtf3_test.c

const qnan128 = @bitCast(f128, @as(u128, 0x7fff800000000000) << 64);
const inf128 = @bitCast(f128, @as(u128, 0x7fff000000000000) << 64);

const __addtf3 = @import("addXf3.zig").__addtf3;

fn test__addtf3(a: f128, b: f128, expected_hi: u64, expected_lo: u64) void {
    const x = __addtf3(a, b);

    const rep = @bitCast(u128, x);
    const hi = @intCast(u64, rep >> 64);
    const lo = @truncate(u64, rep);

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

    @panic("__addtf3 test failure");
}

test "addtf3" {
    test__addtf3(qnan128, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // NaN + any = NaN
    test__addtf3(@bitCast(f128, (@as(u128, 0x7fff000000000000) << 64) | @as(u128, 0x800030000000)), 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // inf + inf = inf
    test__addtf3(inf128, inf128, 0x7fff000000000000, 0x0);

    // inf + any = inf
    test__addtf3(inf128, 0x1.2335653452436234723489432abcdefp+5, 0x7fff000000000000, 0x0);

    // any + any
    test__addtf3(0x1.23456734245345543849abcdefp+5, 0x1.edcba52449872455634654321fp-1, 0x40042afc95c8b579, 0x61e58dd6c51eb77c);
}

const __subtf3 = @import("addXf3.zig").__subtf3;

fn test__subtf3(a: f128, b: f128, expected_hi: u64, expected_lo: u64) void {
    const x = __subtf3(a, b);

    const rep = @bitCast(u128, x);
    const hi = @intCast(u64, rep >> 64);
    const lo = @truncate(u64, rep);

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

    @panic("__subtf3 test failure");
}

test "subtf3" {
    // qNaN - any = qNaN
    test__subtf3(qnan128, 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // NaN + any = NaN
    test__subtf3(@bitCast(f128, (@as(u128, 0x7fff000000000000) << 64) | @as(u128, 0x800030000000)), 0x1.23456789abcdefp+5, 0x7fff800000000000, 0x0);

    // inf - any = inf
    test__subtf3(inf128, 0x1.23456789abcdefp+5, 0x7fff000000000000, 0x0);

    // any + any
    test__subtf3(0x1.234567829a3bcdef5678ade36734p+5, 0x1.ee9d7c52354a6936ab8d7654321fp-1, 0x40041b8af1915166, 0xa44a7bca780a166c);
}

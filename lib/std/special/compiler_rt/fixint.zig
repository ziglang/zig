// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const is_test = @import("builtin").is_test;
const std = @import("std");
const math = std.math;
const Log2Int = std.math.Log2Int;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

const DBG = false;

pub fn fixint(comptime fp_t: type, comptime fixint_t: type, a: fp_t) fixint_t {
    @setRuntimeSafety(is_test);

    const rep_t = switch (fp_t) {
        f32 => u32,
        f64 => u64,
        f128 => u128,
        else => unreachable,
    };
    const significandBits = switch (fp_t) {
        f32 => 23,
        f64 => 52,
        f128 => 112,
        else => unreachable,
    };

    const typeWidth = @typeInfo(rep_t).Int.bits;
    const exponentBits = (typeWidth - significandBits - 1);
    const signBit = (@as(rep_t, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const implicitBit = (@as(rep_t, 1) << significandBits);
    const significandMask = (implicitBit - 1);

    // Break a into sign, exponent, significand
    const aRep: rep_t = @bitCast(rep_t, a);
    const absMask = signBit - 1;
    const aAbs: rep_t = aRep & absMask;

    const negative = (aRep & signBit) != 0;
    const exponent = @intCast(i32, aAbs >> significandBits) - exponentBias;
    const significand: rep_t = (aAbs & significandMask) | implicitBit;

    // If exponent is negative, the uint_result is zero.
    if (exponent < 0) return 0;

    // The unsigned result needs to be large enough to handle an fixint_t or rep_t
    const fixint_bits = @typeInfo(fixint_t).Int.bits;
    const fixuint_t = std.meta.Int(.unsigned, fixint_bits);
    const UintResultType = if (fixint_bits > typeWidth) fixuint_t else rep_t;
    var uint_result: UintResultType = undefined;

    // If the value is too large for the integer type, saturate.
    if (@intCast(usize, exponent) >= fixint_bits) {
        return if (negative) @as(fixint_t, minInt(fixint_t)) else @as(fixint_t, maxInt(fixint_t));
    }

    // If 0 <= exponent < significandBits, right shift else left shift
    if (exponent < significandBits) {
        uint_result = @intCast(UintResultType, significand) >> @intCast(Log2Int(UintResultType), significandBits - exponent);
    } else {
        uint_result = @intCast(UintResultType, significand) << @intCast(Log2Int(UintResultType), exponent - significandBits);
    }

    // Cast to final signed result
    if (negative) {
        return if (uint_result >= -math.minInt(fixint_t)) math.minInt(fixint_t) else -@intCast(fixint_t, uint_result);
    } else {
        return if (uint_result >= math.maxInt(fixint_t)) math.maxInt(fixint_t) else @intCast(fixint_t, uint_result);
    }
}

test "import fixint" {
    _ = @import("fixint_test.zig");
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;

pub fn __extendsfdf2(a: f32) callconv(.C) f64 {
    return @call(.{ .modifier = .always_inline }, extendXfYf2, .{ f64, f32, @bitCast(u32, a) });
}

pub fn __extenddftf2(a: f64) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, extendXfYf2, .{ f128, f64, @bitCast(u64, a) });
}

pub fn __extendsftf2(a: f32) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, extendXfYf2, .{ f128, f32, @bitCast(u32, a) });
}

pub fn __extendhfsf2(a: u16) callconv(.C) f32 {
    return @call(.{ .modifier = .always_inline }, extendXfYf2, .{ f32, f16, a });
}

pub fn __extendhftf2(a: u16) callconv(.C) f128 {
    return @call(.{ .modifier = .always_inline }, extendXfYf2, .{ f128, f16, a });
}

pub fn __aeabi_h2f(arg: u16) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __extendhfsf2, .{arg});
}

pub fn __aeabi_f2d(arg: f32) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __extendsfdf2, .{arg});
}

const CHAR_BIT = 8;

fn extendXfYf2(comptime dst_t: type, comptime src_t: type, a: std.meta.Int(.unsigned, @typeInfo(src_t).Float.bits)) dst_t {
    @setRuntimeSafety(builtin.is_test);

    const src_rep_t = std.meta.Int(.unsigned, @typeInfo(src_t).Float.bits);
    const dst_rep_t = std.meta.Int(.unsigned, @typeInfo(dst_t).Float.bits);
    const srcSigBits = std.math.floatMantissaBits(src_t);
    const dstSigBits = std.math.floatMantissaBits(dst_t);
    const SrcShift = std.math.Log2Int(src_rep_t);
    const DstShift = std.math.Log2Int(dst_rep_t);

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const srcBits = @sizeOf(src_t) * CHAR_BIT;
    const srcExpBits = srcBits - srcSigBits - 1;
    const srcInfExp = (1 << srcExpBits) - 1;
    const srcExpBias = srcInfExp >> 1;

    const srcMinNormal = 1 << srcSigBits;
    const srcInfinity = srcInfExp << srcSigBits;
    const srcSignMask = 1 << (srcSigBits + srcExpBits);
    const srcAbsMask = srcSignMask - 1;
    const srcQNaN = 1 << (srcSigBits - 1);
    const srcNaNCode = srcQNaN - 1;

    const dstBits = @sizeOf(dst_t) * CHAR_BIT;
    const dstExpBits = dstBits - dstSigBits - 1;
    const dstInfExp = (1 << dstExpBits) - 1;
    const dstExpBias = dstInfExp >> 1;

    const dstMinNormal: dst_rep_t = @as(dst_rep_t, 1) << dstSigBits;

    // Break a into a sign and representation of the absolute value
    const aRep: src_rep_t = @bitCast(src_rep_t, a);
    const aAbs: src_rep_t = aRep & srcAbsMask;
    const sign: src_rep_t = aRep & srcSignMask;
    var absResult: dst_rep_t = undefined;

    if (aAbs -% srcMinNormal < srcInfinity - srcMinNormal) {
        // a is a normal number.
        // Extend to the destination type by shifting the significand and
        // exponent into the proper position and rebiasing the exponent.
        absResult = @as(dst_rep_t, aAbs) << (dstSigBits - srcSigBits);
        absResult += (dstExpBias - srcExpBias) << dstSigBits;
    } else if (aAbs >= srcInfinity) {
        // a is NaN or infinity.
        // Conjure the result by beginning with infinity, then setting the qNaN
        // bit (if needed) and right-aligning the rest of the trailing NaN
        // payload field.
        absResult = dstInfExp << dstSigBits;
        absResult |= @as(dst_rep_t, aAbs & srcQNaN) << (dstSigBits - srcSigBits);
        absResult |= @as(dst_rep_t, aAbs & srcNaNCode) << (dstSigBits - srcSigBits);
    } else if (aAbs != 0) {
        // a is denormal.
        // renormalize the significand and clear the leading bit, then insert
        // the correct adjusted exponent in the destination type.
        const scale: u32 = @clz(src_rep_t, aAbs) -
            @clz(src_rep_t, @as(src_rep_t, srcMinNormal));
        absResult = @as(dst_rep_t, aAbs) << @intCast(DstShift, dstSigBits - srcSigBits + scale);
        absResult ^= dstMinNormal;
        const resultExponent: u32 = dstExpBias - srcExpBias - scale + 1;
        absResult |= @intCast(dst_rep_t, resultExponent) << dstSigBits;
    } else {
        // a is zero.
        absResult = 0;
    }

    // Apply the signbit to (dst_t)abs(a).
    const result: dst_rep_t align(@alignOf(dst_t)) = absResult | @as(dst_rep_t, sign) << (dstBits - srcBits);
    return @bitCast(dst_t, result);
}

test "import extendXfYf2" {
    _ = @import("extendXfYf2_test.zig");
}

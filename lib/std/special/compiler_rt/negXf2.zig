// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");

pub fn __negsf2(a: f32) callconv(.C) f32 {
    return negXf2(f32, a);
}

pub fn __negdf2(a: f64) callconv(.C) f64 {
    return negXf2(f64, a);
}

pub fn __aeabi_fneg(arg: f32) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __negsf2, .{arg});
}

pub fn __aeabi_dneg(arg: f64) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __negdf2, .{arg});
}

fn negXf2(comptime T: type, a: T) T {
    const Z = std.meta.Int(false, @typeInfo(T).Float.bits);

    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));

    return @bitCast(T, @bitCast(Z, a) ^ signBit);
}

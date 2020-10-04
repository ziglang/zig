// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std");
const maxInt = std.math.maxInt;

const FLT_MANT_DIG = 24;

fn __floatXisf(comptime T: type, arg: T) f32 {
    @setRuntimeSafety(builtin.is_test);

    const bits = @typeInfo(T).Int.bits;
    const Z = std.meta.Int(false, bits);
    const S = std.meta.Int(false, bits - @clz(Z, @as(Z, bits) - 1));

    if (arg == 0) {
        return @as(f32, 0.0);
    }

    var ai = arg;
    const N: u32 = bits;
    const si = ai >> @intCast(S, (N - 1));
    ai = ((ai ^ si) -% si);
    var a = @bitCast(Z, ai);

    const sd = @bitCast(i32, N - @clz(Z, a)); // number of significant digits
    var e: i32 = sd - 1; // exponent

    if (sd > FLT_MANT_DIG) {
        //  start:  0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQxxxxxxxxxxxxxxxxxx
        //  finish: 000000000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQR
        //                                                12345678901234567890123456
        //  1 = msb 1 bit
        //  P = bit FLT_MANT_DIG-1 bits to the right of 1
        //  Q = bit FLT_MANT_DIG bits to the right of 1
        //  R = "or" of all bits to the right of Q
        switch (sd) {
            FLT_MANT_DIG + 1 => {
                a <<= 1;
            },
            FLT_MANT_DIG + 2 => {},
            else => {
                const shift1_amt = @intCast(i32, sd - (FLT_MANT_DIG + 2));
                const shift1_amt_u7 = @intCast(S, shift1_amt);

                const shift2_amt = @intCast(i32, N + (FLT_MANT_DIG + 2)) - sd;
                const shift2_amt_u7 = @intCast(S, shift2_amt);

                a = (a >> shift1_amt_u7) | @boolToInt((a & (@intCast(Z, maxInt(Z)) >> shift2_amt_u7)) != 0);
            },
        }
        // finish
        a |= @boolToInt((a & 4) != 0); // Or P into R
        a += 1; // round - this step may add a significant bit
        a >>= 2; // dump Q and R
        // a is now rounded to FLT_MANT_DIG or FLT_MANT_DIG+1 bits
        if ((a & (@as(Z, 1) << FLT_MANT_DIG)) != 0) {
            a >>= 1;
            e += 1;
        }
        // a is now rounded to FLT_MANT_DIG bits
    } else {
        a <<= @intCast(S, FLT_MANT_DIG - sd);
        // a is now rounded to FLT_MANT_DIG bits
    }

    const s = @bitCast(Z, arg) >> (@typeInfo(T).Int.bits - 32);
    const r = (@intCast(u32, s) & 0x80000000) | // sign
        (@intCast(u32, (e + 127)) << 23) | // exponent
        (@truncate(u32, a) & 0x007fffff); // mantissa-high

    return @bitCast(f32, r);
}

pub fn __floatdisf(arg: i64) callconv(.C) f32 {
    @setRuntimeSafety(builtin.is_test);
    return @call(.{ .modifier = .always_inline }, __floatXisf, .{ i64, arg });
}

pub fn __floattisf(arg: i128) callconv(.C) f32 {
    @setRuntimeSafety(builtin.is_test);
    return @call(.{ .modifier = .always_inline }, __floatXisf, .{ i128, arg });
}

pub fn __aeabi_l2f(arg: i64) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __floatdisf, .{arg});
}

test "import floattisf" {
    _ = @import("floattisf_test.zig");
}
test "import floatdisf" {
    _ = @import("floattisf_test.zig");
}

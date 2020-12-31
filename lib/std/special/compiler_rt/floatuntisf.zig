// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");
const maxInt = std.math.maxInt;

const FLT_MANT_DIG = 24;

pub fn __floatuntisf(arg: u128) callconv(.C) f32 {
    @setRuntimeSafety(is_test);

    if (arg == 0)
        return 0.0;

    var a = arg;
    const N: u32 = @sizeOf(u128) * 8;
    const sd = @bitCast(i32, N - @clz(u128, a)); // number of significant digits
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
                const shift_amt = @bitCast(i32, N + (FLT_MANT_DIG + 2)) - sd;
                const shift_amt_u7 = @intCast(u7, shift_amt);
                a = (a >> @intCast(u7, sd - (FLT_MANT_DIG + 2))) |
                    @boolToInt((a & (@as(u128, maxInt(u128)) >> shift_amt_u7)) != 0);
            },
        }
        // finish
        a |= @boolToInt((a & 4) != 0); // Or P into R
        a += 1; // round - this step may add a significant bit
        a >>= 2; // dump Q and R
        // a is now rounded to FLT_MANT_DIG or FLT_MANT_DIG+1 bits
        if ((a & (@as(u128, 1) << FLT_MANT_DIG)) != 0) {
            a >>= 1;
            e += 1;
        }
        // a is now rounded to FLT_MANT_DIG bits
    } else {
        a <<= @intCast(u7, FLT_MANT_DIG - sd);
        // a is now rounded to FLT_MANT_DIG bits
    }

    const high = @bitCast(u32, (e + 127) << 23); // exponent
    const low = @truncate(u32, a) & 0x007fffff; // mantissa

    return @bitCast(f32, high | low);
}

test "import floatuntisf" {
    _ = @import("floatuntisf_test.zig");
}

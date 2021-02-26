// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");
const maxInt = std.math.maxInt;

const DBL_MANT_DIG = 53;

pub fn __floatuntidf(arg: u128) callconv(.C) f64 {
    @setRuntimeSafety(is_test);

    if (arg == 0)
        return 0.0;

    var a = arg;
    const N: u32 = @sizeOf(u128) * 8;
    const sd = @bitCast(i32, N - @clz(u128, a)); // number of significant digits
    var e: i32 = sd - 1; // exponent
    if (sd > DBL_MANT_DIG) {
        //  start:  0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQxxxxxxxxxxxxxxxxxx
        //  finish: 000000000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQR
        //                                                12345678901234567890123456
        //  1 = msb 1 bit
        //  P = bit DBL_MANT_DIG-1 bits to the right of 1
        //  Q = bit DBL_MANT_DIG bits to the right of 1
        //  R = "or" of all bits to the right of Q
        switch (sd) {
            DBL_MANT_DIG + 1 => {
                a <<= 1;
            },
            DBL_MANT_DIG + 2 => {},
            else => {
                const shift_amt = @bitCast(i32, N + (DBL_MANT_DIG + 2)) - sd;
                const shift_amt_u7 = @intCast(u7, shift_amt);
                a = (a >> @intCast(u7, sd - (DBL_MANT_DIG + 2))) |
                    @boolToInt((a & (@as(u128, maxInt(u128)) >> shift_amt_u7)) != 0);
            },
        }
        // finish
        a |= @boolToInt((a & 4) != 0); // Or P into R
        a += 1; // round - this step may add a significant bit
        a >>= 2; // dump Q and R
        // a is now rounded to DBL_MANT_DIG or DBL_MANT_DIG+1 bits
        if ((a & (@as(u128, 1) << DBL_MANT_DIG)) != 0) {
            a >>= 1;
            e += 1;
        }
        // a is now rounded to DBL_MANT_DIG bits
    } else {
        a <<= @intCast(u7, DBL_MANT_DIG - sd);
        // a is now rounded to DBL_MANT_DIG bits
    }

    const high: u64 = @bitCast(u32, (e + 1023) << 20) | // exponent
        (@truncate(u32, a >> 32) & 0x000FFFFF); // mantissa-high
    const low = @truncate(u32, a); // mantissa-low

    return @bitCast(f64, low | (high << 32));
}

test "import floatuntidf" {
    _ = @import("floatuntidf_test.zig");
}

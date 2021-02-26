// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const is_test = builtin.is_test;
const std = @import("std");
const maxInt = std.math.maxInt;

const LDBL_MANT_DIG = 113;

pub fn __floattitf(arg: i128) callconv(.C) f128 {
    @setRuntimeSafety(is_test);

    if (arg == 0)
        return 0.0;

    var ai = arg;
    const N: u32 = 128;
    const si = ai >> @intCast(u7, (N - 1));
    ai = ((ai ^ si) -% si);
    var a = @bitCast(u128, ai);

    const sd = @bitCast(i32, N - @clz(u128, a)); // number of significant digits
    var e: i32 = sd - 1; // exponent
    if (sd > LDBL_MANT_DIG) {
        //  start:  0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQxxxxxxxxxxxxxxxxxx
        //  finish: 000000000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQR
        //                                                12345678901234567890123456
        //  1 = msb 1 bit
        //  P = bit LDBL_MANT_DIG-1 bits to the right of 1
        //  Q = bit LDBL_MANT_DIG bits to the right of 1
        //  R = "or" of all bits to the right of Q
        switch (sd) {
            LDBL_MANT_DIG + 1 => {
                a <<= 1;
            },
            LDBL_MANT_DIG + 2 => {},
            else => {
                const shift1_amt = @intCast(i32, sd - (LDBL_MANT_DIG + 2));
                const shift1_amt_u7 = @intCast(u7, shift1_amt);

                const shift2_amt = @intCast(i32, N + (LDBL_MANT_DIG + 2)) - sd;
                const shift2_amt_u7 = @intCast(u7, shift2_amt);

                a = (a >> shift1_amt_u7) | @boolToInt((a & (@intCast(u128, maxInt(u128)) >> shift2_amt_u7)) != 0);
            },
        }
        // finish
        a |= @boolToInt((a & 4) != 0); // Or P into R
        a += 1; // round - this step may add a significant bit
        a >>= 2; // dump Q and R
        // a is now rounded to LDBL_MANT_DIG or LDBL_MANT_DIG+1 bits
        if ((a & (@as(u128, 1) << LDBL_MANT_DIG)) != 0) {
            a >>= 1;
            e += 1;
        }
        // a is now rounded to LDBL_MANT_DIG bits
    } else {
        a <<= @intCast(u7, LDBL_MANT_DIG - sd);
        // a is now rounded to LDBL_MANT_DIG bits
    }

    const s = @bitCast(u128, arg) >> (128 - 64);
    const high: u128 = (@intCast(u64, s) & 0x8000000000000000) | // sign
        (@intCast(u64, (e + 16383)) << 48) | // exponent
        (@truncate(u64, a >> 64) & 0x0000ffffffffffff); // mantissa-high
    const low = @truncate(u64, a); // mantissa-low

    return @bitCast(f128, low | (high << 64));
}

test "import floattitf" {
    _ = @import("floattitf_test.zig");
}

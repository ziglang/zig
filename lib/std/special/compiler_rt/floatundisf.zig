// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = @import("builtin");
const std = @import("std");
const maxInt = std.math.maxInt;

const FLT_MANT_DIG = 24;

pub fn __floatundisf(arg: u64) callconv(.C) f32 {
    @setRuntimeSafety(builtin.is_test);

    if (arg == 0) return 0;

    var a = arg;
    const N: usize = @typeInfo(@TypeOf(a)).Int.bits;
    // Number of significant digits
    const sd = N - @clz(u64, a);
    // 8 exponent
    var e = @intCast(u32, sd) - 1;

    if (sd > FLT_MANT_DIG) {
        //  start:  0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQxxxxxxxxxxxxxxxxxx
        //  finish: 000000000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxPQR
        //                                                12345678901234567890123456
        //  1 = msb 1 bit
        //  P = bit FLT_MANT_DIG-1 bits to the right of 1
        //  Q = bit FLT_MANT_DIG bits to the right of 1
        //  R = "or" of all bits to the right of Q
        switch (sd) {
            FLT_MANT_DIG + 1 => a <<= 1,
            FLT_MANT_DIG + 2 => {},
            else => {
                const shift_amt = @intCast(u6, ((N + FLT_MANT_DIG + 2) - sd));
                const all_ones: u64 = maxInt(u64);
                a = (a >> @intCast(u6, sd - (FLT_MANT_DIG + 2))) |
                    @boolToInt(a & (all_ones >> shift_amt) != 0);
            },
        }
        // Or P into R
        a |= @boolToInt((a & 4) != 0);
        // round - this step may add a significant bit
        a += 1;
        // dump Q and R
        a >>= 2;
        // a is now rounded to FLT_MANT_DIG or FLT_MANT_DIG+1 bits
        if ((a & (@as(u64, 1) << FLT_MANT_DIG)) != 0) {
            a >>= 1;
            e += 1;
        }
        // a is now rounded to FLT_MANT_DIG bits
    } else {
        a <<= @intCast(u6, FLT_MANT_DIG - sd);
        // a is now rounded to FLT_MANT_DIG bits
    }

    const result: u32 = ((e + 127) << 23) | // exponent
        @truncate(u32, a & 0x007FFFFF); // mantissa
    return @bitCast(f32, result);
}

pub fn __aeabi_ul2f(arg: u64) callconv(.AAPCS) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __floatundisf, .{arg});
}

fn test__floatundisf(a: u64, expected: f32) void {
    std.testing.expectEqual(expected, __floatundisf(a));
}

test "floatundisf" {
    test__floatundisf(0, 0.0);
    test__floatundisf(1, 1.0);
    test__floatundisf(2, 2.0);
    test__floatundisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    test__floatundisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    test__floatundisf(0x8000008000000000, 0x1p+63);
    test__floatundisf(0x8000010000000000, 0x1.000002p+63);
    test__floatundisf(0x8000000000000000, 0x1p+63);
    test__floatundisf(0x8000000000000001, 0x1p+63);
    test__floatundisf(0xFFFFFFFFFFFFFFFE, 0x1p+64);
    test__floatundisf(0xFFFFFFFFFFFFFFFF, 0x1p+64);
    test__floatundisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    test__floatundisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    test__floatundisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);
}

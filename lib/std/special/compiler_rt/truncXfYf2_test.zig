// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const __truncsfhf2 = @import("truncXfYf2.zig").__truncsfhf2;

fn test__truncsfhf2(a: u32, expected: u16) void {
    const actual = __truncsfhf2(@bitCast(f32, a));

    if (actual == expected) {
        return;
    }

    @panic("__truncsfhf2 test failure");
}

test "truncsfhf2" {
    test__truncsfhf2(0x7fc00000, 0x7e00); // qNaN
    test__truncsfhf2(0x7fe00000, 0x7f00); // sNaN

    test__truncsfhf2(0, 0); // 0
    test__truncsfhf2(0x80000000, 0x8000); // -0

    test__truncsfhf2(0x7f800000, 0x7c00); // inf
    test__truncsfhf2(0xff800000, 0xfc00); // -inf

    test__truncsfhf2(0x477ff000, 0x7c00); // 65520 -> inf
    test__truncsfhf2(0xc77ff000, 0xfc00); // -65520 -> -inf

    test__truncsfhf2(0x71cc3892, 0x7c00); // 0x1.987124876876324p+100 -> inf
    test__truncsfhf2(0xf1cc3892, 0xfc00); // -0x1.987124876876324p+100 -> -inf

    test__truncsfhf2(0x38800000, 0x0400); // normal (min), 2**-14
    test__truncsfhf2(0xb8800000, 0x8400); // normal (min), -2**-14

    test__truncsfhf2(0x477fe000, 0x7bff); // normal (max), 65504
    test__truncsfhf2(0xc77fe000, 0xfbff); // normal (max), -65504

    test__truncsfhf2(0x477fe100, 0x7bff); // normal, 65505 -> 65504
    test__truncsfhf2(0xc77fe100, 0xfbff); // normal, -65505 -> -65504

    test__truncsfhf2(0x477fef00, 0x7bff); // normal, 65519 -> 65504
    test__truncsfhf2(0xc77fef00, 0xfbff); // normal, -65519 -> -65504

    test__truncsfhf2(0x3f802000, 0x3c01); // normal, 1 + 2**-10
    test__truncsfhf2(0xbf802000, 0xbc01); // normal, -1 - 2**-10

    test__truncsfhf2(0x3eaaa000, 0x3555); // normal, approx. 1/3
    test__truncsfhf2(0xbeaaa000, 0xb555); // normal, approx. -1/3

    test__truncsfhf2(0x40490fdb, 0x4248); // normal, 3.1415926535
    test__truncsfhf2(0xc0490fdb, 0xc248); // normal, -3.1415926535

    test__truncsfhf2(0x45cc3892, 0x6e62); // normal, 0x1.987124876876324p+12

    test__truncsfhf2(0x3f800000, 0x3c00); // normal, 1
    test__truncsfhf2(0x38800000, 0x0400); // normal, 0x1.0p-14

    test__truncsfhf2(0x33800000, 0x0001); // denormal (min), 2**-24
    test__truncsfhf2(0xb3800000, 0x8001); // denormal (min), -2**-24

    test__truncsfhf2(0x387fc000, 0x03ff); // denormal (max), 2**-14 - 2**-24
    test__truncsfhf2(0xb87fc000, 0x83ff); // denormal (max), -2**-14 + 2**-24

    test__truncsfhf2(0x35800000, 0x0010); // denormal, 0x1.0p-20
    test__truncsfhf2(0x33280000, 0x0001); // denormal, 0x1.5p-25 -> 0x1.0p-24
    test__truncsfhf2(0x33000000, 0x0000); // 0x1.0p-25 -> zero
}

const __truncdfhf2 = @import("truncXfYf2.zig").__truncdfhf2;

fn test__truncdfhf2(a: f64, expected: u16) void {
    const rep = @bitCast(u16, __truncdfhf2(a));

    if (rep == expected) {
        return;
    }
    // test other possible NaN representation(signal NaN)
    else if (expected == 0x7e00) {
        if ((rep & 0x7c00) == 0x7c00 and (rep & 0x3ff) > 0) {
            return;
        }
    }

    @panic("__truncdfhf2 test failure");
}

fn test__truncdfhf2_raw(a: u64, expected: u16) void {
    const actual = __truncdfhf2(@bitCast(f64, a));

    if (actual == expected) {
        return;
    }

    @panic("__truncdfhf2 test failure");
}

test "truncdfhf2" {
    test__truncdfhf2_raw(0x7ff8000000000000, 0x7e00); // qNaN
    test__truncdfhf2_raw(0x7ff0000000008000, 0x7e00); // NaN

    test__truncdfhf2_raw(0x7ff0000000000000, 0x7c00); //inf
    test__truncdfhf2_raw(0xfff0000000000000, 0xfc00); // -inf

    test__truncdfhf2(0.0, 0x0); // zero
    test__truncdfhf2_raw(0x80000000 << 32, 0x8000); // -zero

    test__truncdfhf2(3.1415926535, 0x4248);
    test__truncdfhf2(-3.1415926535, 0xc248);

    test__truncdfhf2(0x1.987124876876324p+1000, 0x7c00);
    test__truncdfhf2(0x1.987124876876324p+12, 0x6e62);
    test__truncdfhf2(0x1.0p+0, 0x3c00);
    test__truncdfhf2(0x1.0p-14, 0x0400);

    // denormal
    test__truncdfhf2(0x1.0p-20, 0x0010);
    test__truncdfhf2(0x1.0p-24, 0x0001);
    test__truncdfhf2(-0x1.0p-24, 0x8001);
    test__truncdfhf2(0x1.5p-25, 0x0001);

    // and back to zero
    test__truncdfhf2(0x1.0p-25, 0x0000);
    test__truncdfhf2(-0x1.0p-25, 0x8000);

    // max (precise)
    test__truncdfhf2(65504.0, 0x7bff);

    // max (rounded)
    test__truncdfhf2(65519.0, 0x7bff);

    // max (to +inf)
    test__truncdfhf2(65520.0, 0x7c00);
    test__truncdfhf2(-65520.0, 0xfc00);
    test__truncdfhf2(65536.0, 0x7c00);
}

const __trunctfsf2 = @import("truncXfYf2.zig").__trunctfsf2;

fn test__trunctfsf2(a: f128, expected: u32) void {
    const x = __trunctfsf2(a);

    const rep = @bitCast(u32, x);
    if (rep == expected) {
        return;
    }
    // test other possible NaN representation(signal NaN)
    else if (expected == 0x7fc00000) {
        if ((rep & 0x7f800000) == 0x7f800000 and (rep & 0x7fffff) > 0) {
            return;
        }
    }

    @panic("__trunctfsf2 test failure");
}

test "trunctfsf2" {
    // qnan
    test__trunctfsf2(@bitCast(f128, @as(u128, 0x7fff800000000000 << 64)), 0x7fc00000);
    // nan
    test__trunctfsf2(@bitCast(f128, @as(u128, (0x7fff000000000000 | (0x810000000000 & 0xffffffffffff)) << 64)), 0x7fc08000);
    // inf
    test__trunctfsf2(@bitCast(f128, @as(u128, 0x7fff000000000000 << 64)), 0x7f800000);
    // zero
    test__trunctfsf2(0.0, 0x0);

    test__trunctfsf2(0x1.23a2abb4a2ddee355f36789abcdep+5, 0x4211d156);
    test__trunctfsf2(0x1.e3d3c45bd3abfd98b76a54cc321fp-9, 0x3b71e9e2);
    test__trunctfsf2(0x1.234eebb5faa678f4488693abcdefp+4534, 0x7f800000);
    test__trunctfsf2(0x1.edcba9bb8c76a5a43dd21f334634p-435, 0x0);
}

const __trunctfdf2 = @import("truncXfYf2.zig").__trunctfdf2;

fn test__trunctfdf2(a: f128, expected: u64) void {
    const x = __trunctfdf2(a);

    const rep = @bitCast(u64, x);
    if (rep == expected) {
        return;
    }
    // test other possible NaN representation(signal NaN)
    else if (expected == 0x7ff8000000000000) {
        if ((rep & 0x7ff0000000000000) == 0x7ff0000000000000 and (rep & 0xfffffffffffff) > 0) {
            return;
        }
    }

    @panic("__trunctfsf2 test failure");
}

test "trunctfdf2" {
    // qnan
    test__trunctfdf2(@bitCast(f128, @as(u128, 0x7fff800000000000 << 64)), 0x7ff8000000000000);
    // nan
    test__trunctfdf2(@bitCast(f128, @as(u128, (0x7fff000000000000 | (0x810000000000 & 0xffffffffffff)) << 64)), 0x7ff8100000000000);
    // inf
    test__trunctfdf2(@bitCast(f128, @as(u128, 0x7fff000000000000 << 64)), 0x7ff0000000000000);
    // zero
    test__trunctfdf2(0.0, 0x0);

    test__trunctfdf2(0x1.af23456789bbaaab347645365cdep+5, 0x404af23456789bbb);
    test__trunctfdf2(0x1.dedafcff354b6ae9758763545432p-9, 0x3f6dedafcff354b7);
    test__trunctfdf2(0x1.2f34dd5f437e849b4baab754cdefp+4534, 0x7ff0000000000000);
    test__trunctfdf2(0x1.edcbff8ad76ab5bf46463233214fp-435, 0x24cedcbff8ad76ab);
}

const __truncdfsf2 = @import("truncXfYf2.zig").__truncdfsf2;

fn test__truncdfsf2(a: f64, expected: u32) void {
    const x = __truncdfsf2(a);

    const rep = @bitCast(u32, x);
    if (rep == expected) {
        return;
    }
    // test other possible NaN representation(signal NaN)
    else if (expected == 0x7fc00000) {
        if ((rep & 0x7f800000) == 0x7f800000 and (rep & 0x7fffff) > 0) {
            return;
        }
    }

    @import("std").debug.warn("got 0x{x} wanted 0x{x}\n", .{ rep, expected });

    @panic("__trunctfsf2 test failure");
}

test "truncdfsf2" {
    // nan & qnan
    test__truncdfsf2(@bitCast(f64, @as(u64, 0x7ff8000000000000)), 0x7fc00000);
    test__truncdfsf2(@bitCast(f64, @as(u64, 0x7ff0000000000001)), 0x7fc00000);
    // inf
    test__truncdfsf2(@bitCast(f64, @as(u64, 0x7ff0000000000000)), 0x7f800000);
    test__truncdfsf2(@bitCast(f64, @as(u64, 0xfff0000000000000)), 0xff800000);

    test__truncdfsf2(0.0, 0x0);
    test__truncdfsf2(1.0, 0x3f800000);
    test__truncdfsf2(-1.0, 0xbf800000);

    // huge number becomes inf
    test__truncdfsf2(340282366920938463463374607431768211456.0, 0x7f800000);
}

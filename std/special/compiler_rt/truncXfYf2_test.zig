const __truncsfhf2 = @import("truncXfYf2.zig").__truncsfhf2;

fn test__truncsfhf2(a: u32, expected: u16) void {
    const actual = __truncsfhf2(@bitCast(f32, a));

    if (actual == expected) {
        return;
    }

    @panic("__truncsfhf2 test failure");
}

test "truncsfhf2" {
    test__truncsfhf2(0x7fc00000, 0x7e00);  // qNaN
    test__truncsfhf2(0x7fe00000, 0x7f00);  // sNaN

    test__truncsfhf2(0, 0);  // 0
    test__truncsfhf2(0x80000000, 0x8000);  // -0

    test__truncsfhf2(0x7f800000, 0x7c00);  // inf
    test__truncsfhf2(0xff800000, 0xfc00);  // -inf

    test__truncsfhf2(0x477ff000, 0x7c00);  // 65520 -> inf
    test__truncsfhf2(0xc77ff000, 0xfc00);  // -65520 -> -inf

    test__truncsfhf2(0x71cc3892, 0x7c00);  // 0x1.987124876876324p+100 -> inf
    test__truncsfhf2(0xf1cc3892, 0xfc00);  // -0x1.987124876876324p+100 -> -inf

    test__truncsfhf2(0x38800000, 0x0400);  // normal (min), 2**-14
    test__truncsfhf2(0xb8800000, 0x8400);  // normal (min), -2**-14

    test__truncsfhf2(0x477fe000, 0x7bff);  // normal (max), 65504
    test__truncsfhf2(0xc77fe000, 0xfbff);  // normal (max), -65504

    test__truncsfhf2(0x477fe100, 0x7bff);  // normal, 65505 -> 65504
    test__truncsfhf2(0xc77fe100, 0xfbff);  // normal, -65505 -> -65504

    test__truncsfhf2(0x477fef00, 0x7bff);  // normal, 65519 -> 65504
    test__truncsfhf2(0xc77fef00, 0xfbff);  // normal, -65519 -> -65504

    test__truncsfhf2(0x3f802000, 0x3c01);  // normal, 1 + 2**-10
    test__truncsfhf2(0xbf802000, 0xbc01);  // normal, -1 - 2**-10

    test__truncsfhf2(0x3eaaa000, 0x3555);  // normal, approx. 1/3
    test__truncsfhf2(0xbeaaa000, 0xb555);  // normal, approx. -1/3

    test__truncsfhf2(0x40490fdb, 0x4248);  // normal, 3.1415926535
    test__truncsfhf2(0xc0490fdb, 0xc248);  // normal, -3.1415926535

    test__truncsfhf2(0x45cc3892, 0x6e62);  // normal, 0x1.987124876876324p+12

    test__truncsfhf2(0x3f800000, 0x3c00);  // normal, 1
    test__truncsfhf2(0x38800000, 0x0400);  // normal, 0x1.0p-14

    test__truncsfhf2(0x33800000, 0x0001);  // denormal (min), 2**-24
    test__truncsfhf2(0xb3800000, 0x8001);  // denormal (min), -2**-24

    test__truncsfhf2(0x387fc000, 0x03ff);  // denormal (max), 2**-14 - 2**-24
    test__truncsfhf2(0xb87fc000, 0x83ff);  // denormal (max), -2**-14 + 2**-24

    test__truncsfhf2(0x35800000, 0x0010);  // denormal, 0x1.0p-20
    test__truncsfhf2(0x33280000, 0x0001);  // denormal, 0x1.5p-25 -> 0x1.0p-24
    test__truncsfhf2(0x33000000, 0x0000);  // 0x1.0p-25 -> zero
}

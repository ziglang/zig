const math = @import("../../math.zig");
const test_utils = @import("../test.zig");
const Testcase = test_utils.Testcase;
const runTests = test_utils.runTests;
const floatFromBits = test_utils.floatFromBits;
const negInf = test_utils.negInf;
const nan32 = math.nan_f32;
const nan64 = math.nan_f64;

const Tc32 = Testcase(math.log2, "log2", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.log2, "log2", f64);
const tc64 = Tc64.init;

// Special-case tests shared between different float sizes, see genTests().
const special_tests = .{
    // zig fmt: off
    .{ 0,        negInf  },
    .{-0,        negInf  },
    .{ 1,        0       },
    .{ 2,        1       },
    .{-1,        math.nan},
    .{ math.inf, math.inf},
    .{ negInf,   math.nan},
    // zig fmt: on
};

test "math.log2_32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3,  nan32        ),
        tc32( 0x1.161868p+2,  0x1.0f49acp+1),
        tc32(-0x1.0c34b4p+3,  nan32        ),
        tc32(-0x1.a206f0p+2,  nan32        ),
        tc32( 0x1.288bbcp+3,  0x1.9b2676p+1),
        tc32( 0x1.52efd0p-1, -0x1.30b494p-1), // Disagrees with GCC in last bit
        tc32(-0x1.a05cc8p-2,  nan32        ),
        tc32( 0x1.1f9efap-1, -0x1.a9f89ap-1),
        tc32( 0x1.8c5db0p-1, -0x1.7a2c96p-2),
        tc32(-0x1.5b86eap-1,  nan32        ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log2_32() special" {
    const cases = test_utils.genTests(Tc32, special_tests) ++ test_utils.nanTests(Tc32);
    try runTests(cases);
}

test "math.log2_32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32( 0x1.fffffep+127,  0x1p+7        ), // Max input value
        tc32( 0x1p-149,        -0x1.2ap+7     ), // Min positive input value
        tc32(-0x1p-149,         nan32         ), // Min negative input value
        tc32( 0x1.000002p+0,    0x1.715474p-23), // Last value before result reaches +0
        tc32( 0x1.fffffep-1,   -0x1.715478p-24), // Last value before result reaches -0
        tc32( 0x1p-126,        -0x1.f8p+6     ), // First subnormal
        tc32(-0x1p-126,         nan32         ), // First negative subnormal
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log2_64() sanity" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3,  nan64               ),
        tc64( 0x1.161868e18bc67p+2,  0x1.0f49ac3838580p+1),
        tc64(-0x1.0c34b3e01e6e7p+3,  nan64               ),
        tc64(-0x1.a206f0a19dcc4p+2,  nan64               ),
        tc64( 0x1.288bbb0d6a1e6p+3,  0x1.9b26760c2a57ep+1),
        tc64( 0x1.52efd0cd80497p-1, -0x1.30b490ef684c7p-1),
        tc64(-0x1.a05cc754481d1p-2,  nan64               ),
        tc64( 0x1.1f9ef934745cbp-1, -0x1.a9f89b5f5acb8p-1),
        tc64( 0x1.8c5db097f7442p-1, -0x1.7a2c947173f06p-2),
        tc64(-0x1.5b86ea8118a0ep-1,  nan64               ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log2_64() special" {
    const cases = test_utils.genTests(Tc64, special_tests) ++ test_utils.nanTests(Tc64);
    try runTests(cases);
}

test "math.log2_64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64( 0x1.fffffffffffffp+1023,  0x1p+10              ), // Max input value
        tc64( 0x1p-1074,               -0x1.0c8p+10          ), // Min positive input value
        tc64(-0x1p-1074,                nan64                ), // Min negative input value
        tc64( 0x1.0000000000001p+0,     0x1.71547652b82fdp-52), // Last value before result reaches +0
        tc64( 0x1.fffffffffffffp-1,    -0x1.71547652b82fep-53), // Last value before result reaches -0
        tc64( 0x1p-1022,               -0x1.ffp+9            ), // First subnormal
        tc64(-0x1p-1022,                nan64                ), // First negative subnormal
        // zig fmt: on
    };
    try runTests(cases);
}

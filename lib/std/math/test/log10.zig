const math = @import("../../math.zig");
const test_utils = @import("../test.zig");
const Testcase = test_utils.Testcase;
const runTests = test_utils.runTests;
const floatFromBits = test_utils.floatFromBits;
const negInf = test_utils.negInf;
const nan32 = math.nan_f32;
const nan64 = math.nan_f64;

const Tc32 = Testcase(math.log10, "log10", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.log10, "log10", f64);
const tc64 = Tc64.init;

// in -> out
// [-inf,   0) -> nan
// [   0,   1] -> [-inf,   0]
// [   1, inf] -> [   0, inf]

// Special-case tests shared between different float sizes, see genTests().
const special_tests = .{
    // zig fmt: off
    .{ 0,         negInf  },
    .{-0,         negInf  },
    .{ 1,         0       },
    .{ 10,        1       },
    .{ 0.1,      -1       },
    .{-1,         math.nan},
    .{ math.inf,  math.inf},
    .{ negInf,    math.nan},
    // zig fmt: on
};

test "math.log10_32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3,  nan32        ),
        tc32( 0x1.161868p+2,  0x1.46a9bcp-1),
        tc32(-0x1.0c34b4p+3,  nan32        ),
        tc32(-0x1.a206f0p+2,  nan32        ),
        tc32( 0x1.288bbcp+3,  0x1.ef1300p-1),
        tc32( 0x1.52efd0p-1, -0x1.6ee6dcp-3), // Disagrees with GCC in last bit
        tc32(-0x1.a05cc8p-2,  nan32        ),
        tc32( 0x1.1f9efap-1, -0x1.0075ccp-2),
        tc32( 0x1.8c5db0p-1, -0x1.c75df8p-4),
        tc32(-0x1.5b86eap-1,  nan32        ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log10_32() special" {
    const cases = test_utils.genTests(Tc32, special_tests) ++ test_utils.nanTests(Tc32);
    try runTests(cases);
}

test "math.log10_32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32( 0x1.fffffep+127,  0x1.344136p+5 ), // Max input value
        tc32( 0x1p-149,        -0x1.66d3e8p+5 ), // Min positive input value
        tc32(-0x1p-149,         nan32         ), // Min negative input value
        tc32( 0x1.000002p+0,    0x1.bcb7b0p-25), // Last value before result reaches +0
        tc32( 0x1.fffffep-1,   -0x1.bcb7b2p-26), // Last value before result reaches -0
        tc32( 0x1p-126,        -0x1.2f7030p+5 ), // First subnormal
        tc32(-0x1p-126,         nan32         ), // First negative subnormal
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log10_64() sanity" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3,  nan64               ),
        tc64( 0x1.161868e18bc67p+2,  0x1.46a9bd1d2eb87p-1),
        tc64(-0x1.0c34b3e01e6e7p+3,  nan64               ),
        tc64(-0x1.a206f0a19dcc4p+2,  nan64               ),
        tc64( 0x1.288bbb0d6a1e6p+3,  0x1.ef12fff994862p-1),
        tc64( 0x1.52efd0cd80497p-1, -0x1.6ee6db5a155cbp-3),
        tc64(-0x1.a05cc754481d1p-2,  nan64               ),
        tc64( 0x1.1f9ef934745cbp-1, -0x1.0075cda79d321p-2),
        tc64( 0x1.8c5db097f7442p-1, -0x1.c75df6442465ap-4),
        tc64(-0x1.5b86ea8118a0ep-1,  nan64               ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log10_64() special" {
    const cases = test_utils.genTests(Tc64, special_tests) ++ test_utils.nanTests(Tc64);
    try runTests(cases);
}

test "math.log10_64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64( 0x1.fffffffffffffp+1023,  0x1.34413509f79ffp+8 ), // Max input value
        tc64( 0x1p-1074,               -0x1.434e6420f4374p+8 ), // Min positive input value
        tc64(-0x1p-1074,                nan64                ), // Min negative input value
        tc64( 0x1.0000000000001p+0,     0x1.bcb7b1526e50dp-54), // Last value before result reaches +0
        tc64( 0x1.fffffffffffffp-1,    -0x1.bcb7b1526e50fp-55), // Last value before result reaches -0
        tc64( 0x1p-1022,               -0x1.33a7146f72a42p+8 ), // First subnormal
        tc64(-0x1p-1022,                nan64                ), // First negative subnormal
        // zig fmt: on
    };
    try runTests(cases);
}

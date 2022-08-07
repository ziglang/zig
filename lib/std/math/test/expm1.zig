const math = @import("../../math.zig");
const test_utils = @import("../test.zig");
const Testcase = test_utils.Testcase;
const runTests = test_utils.runTests;
const floatFromBits = test_utils.floatFromBits;
const negInf = test_utils.negInf;
const inf32 = math.inf_f32;
const inf64 = math.inf_f64;

const Tc32 = Testcase(math.expm1, "expm1", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.expm1, "expm1", f64);
const tc64 = Tc64.init;

// in -> out
// [-inf,   0] -> [-1,   0]
// [   0, inf] -> [ 0, inf]

// Special-case tests shared between different float sizes, see genTests().
const special_tests = .{
    // zig fmt: off
    .{ 0,         0       },
    .{-0,         0       },
    .{ math.ln2,  1       },
    .{ math.inf,  math.inf},
    .{ negInf,   -1       },
    // zig fmt: on
};

test "math.expm1_32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3, -0x1.ffd6e0p-1 ),
        tc32( 0x1.161868p+2,  0x1.30712ap+6 ),
        tc32(-0x1.0c34b4p+3, -0x1.ffe1fap-1 ),
        tc32(-0x1.a206f0p+2, -0x1.ff4116p-1 ),
        tc32( 0x1.288bbcp+3,  0x1.4ab480p+13), // Disagrees with GCC in last bit
        tc32( 0x1.52efd0p-1,  0x1.e09536p-1 ),
        tc32(-0x1.a05cc8p-2, -0x1.561c3ep-2 ),
        tc32( 0x1.1f9efap-1,  0x1.81ec4ep-1 ),
        tc32( 0x1.8c5db0p-1,  0x1.2b3364p+0 ),
        tc32(-0x1.5b86eap-1, -0x1.f8951ap-2 ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expm1_32() special" {
    const cases = test_utils.genTests(Tc32, special_tests) ++ test_utils.nanTests(Tc32);
    try runTests(cases);
}

test "math.expm1_32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        // TODO: The last value before inf is actually 0x1.62e300p+6 -> 0x1.ff681ep+127
        // tc32( 0x1.62e42ep+6,    0x1.ffff08p+127), // Last value before result is inf
        tc32( 0x1.62e430p+6,    inf32          ), // First value that gives inf
        tc32( 0x1.fffffep+127,  inf32          ), // Max input value
        tc32( 0x1p-149,         0x1p-149       ), // Min positive input value
        tc32(-0x1p-149,        -0x1p-149       ), // Min negative input value
        tc32( 0x1p-126,         0x1p-126       ), // First positive subnormal input
        tc32(-0x1p-126,        -0x1p-126       ), // First negative subnormal input
        tc32( 0x1.fffffep-125,  0x1.fffffep-125), // Last positive value before subnormal
        tc32(-0x1.fffffep-125, -0x1.fffffep-125), // Last negative value before subnormal
        tc32(-0x1.154244p+4,   -0x1.fffffep-1  ), // Last value before result is -1
        tc32(-0x1.154246p+4,   -1              ), // First value where result is -1
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expm1_64() sanity" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3, -0x1.ffd6df9b02b3ep-1 ),
        tc64( 0x1.161868e18bc67p+2,  0x1.30712ed238c04p+6 ),
        tc64(-0x1.0c34b3e01e6e7p+3, -0x1.ffe1f94e493e7p-1 ),
        tc64(-0x1.a206f0a19dcc4p+2, -0x1.ff4115c03f78dp-1 ),
        tc64( 0x1.288bbb0d6a1e6p+3,  0x1.4ab477496e07ep+13),
        tc64( 0x1.52efd0cd80497p-1,  0x1.e095382100a01p-1 ),
        tc64(-0x1.a05cc754481d1p-2, -0x1.561c3e0582be6p-2 ),
        tc64( 0x1.1f9ef934745cbp-1,  0x1.81ec4cd4d4a8fp-1 ),
        tc64( 0x1.8c5db097f7442p-1,  0x1.2b3363a944bf7p+0 ),
        tc64(-0x1.5b86ea8118a0ep-1, -0x1.f8951aebffbafp-2 ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expm1_64() special" {
    const cases = test_utils.genTests(Tc64, special_tests) ++ test_utils.nanTests(Tc64);
    try runTests(cases);
}

test "math.expm1_64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64( 0x1.62e42fefa39efp+9,     0x1.fffffffffff2ap+1023), // Last value before result is inf
        tc64( 0x1.62e42fefa39f0p+9,     inf64                  ), // First value that gives inf
        tc64( 0x1.fffffffffffffp+1023,  inf64                  ), // Max input value
        tc64( 0x1p-1074,                0x1p-1074              ), // Min positive input value
        tc64(-0x1p-1074,               -0x1p-1074              ), // Min negative input value
        tc64( 0x1p-1022,                0x1p-1022              ), // First positive subnormal input
        tc64(-0x1p-1022,               -0x1p-1022              ), // First negative subnormal input
        tc64( 0x1.fffffffffffffp-1021,  0x1.fffffffffffffp-1021), // Last positive value before subnormal
        tc64(-0x1.fffffffffffffp-1021, -0x1.fffffffffffffp-1021), // Last negative value before subnormal
        tc64(-0x1.2b708872320e1p+5,    -0x1.fffffffffffffp-1   ), // Last value before result is -1
        tc64(-0x1.2b708872320e2p+5,    -1                      ), // First value where result is -1
        // zig fmt: on
    };
    try runTests(cases);
}

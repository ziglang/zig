const math = @import("../../math.zig");
const test_utils = @import("../test.zig");
const Testcase = test_utils.Testcase;
const runTests = test_utils.runTests;
const floatFromBits = test_utils.floatFromBits;
const negInf = test_utils.negInf;
const nan32 = math.nan_f32;
const nan64 = math.nan_f64;

const Tc32 = Testcase(math.log1p, "log1p", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.log1p, "log1p", f64);
const tc64 = Tc64.init;

// Special-case tests shared between different float sizes, see genTests().
const special_tests = .{
    // zig fmt: off
    .{ 0,         0       },
    .{-0,        -0       },
    .{-1,         negInf  },
    .{ 1,         math.ln2},
    .{-2,         math.nan},
    .{ math.inf,  math.inf},
    .{ negInf,    math.nan},
    // zig fmt: on
};

test "math.log1p_32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3,  nan32        ),
        tc32( 0x1.161868p+2,  0x1.ad1bdcp+0),
        tc32(-0x1.0c34b4p+3,  nan32        ),
        tc32(-0x1.a206f0p+2,  nan32        ),
        tc32( 0x1.288bbcp+3,  0x1.2a1ab8p+1),
        tc32( 0x1.52efd0p-1,  0x1.041a4ep-1),
        tc32(-0x1.a05cc8p-2, -0x1.0b3596p-1),
        tc32( 0x1.1f9efap-1,  0x1.c88344p-2),
        tc32( 0x1.8c5db0p-1,  0x1.258a8ep-1),
        tc32(-0x1.5b86eap-1, -0x1.22b542p+0),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log1p_32() special" {
    const cases = test_utils.genTests(Tc32, special_tests) ++ test_utils.nanTests(Tc32);
    try runTests(cases);
}

test "math.log1p_32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32( 0x1.fffffep+127,  0x1.62e430p+6), // Max input value
        tc32( 0x1p-149,         0x1p-149     ), // Min positive input value
        tc32(-0x1p-149,        -0x1p-149     ), // Min negative input value
        tc32( 0x1p-126,         0x1p-126     ), // First subnormal
        tc32(-0x1p-126,        -0x1p-126     ), // First negative subnormal
        tc32(-0x1.fffffep-1,   -0x1.0a2b24p+4), // Last value before result is -inf
        tc32(-0x1.000002p+0,    nan32        ), // First value where result is nan
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log1p_64() sanity" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3,  nan64               ),
        tc64( 0x1.161868e18bc67p+2,  0x1.ad1bdd1e9e686p+0), // Disagrees with GCC in last bit
        tc64(-0x1.0c34b3e01e6e7p+3,  nan64               ),
        tc64(-0x1.a206f0a19dcc4p+2,  nan64               ),
        tc64( 0x1.288bbb0d6a1e6p+3,  0x1.2a1ab8365b56fp+1),
        tc64( 0x1.52efd0cd80497p-1,  0x1.041a4ec2a680ap-1),
        tc64(-0x1.a05cc754481d1p-2, -0x1.0b3595423aec1p-1),
        tc64( 0x1.1f9ef934745cbp-1,  0x1.c8834348a846ep-2),
        tc64( 0x1.8c5db097f7442p-1,  0x1.258a8e8a35bbfp-1),
        tc64(-0x1.5b86ea8118a0ep-1, -0x1.22b5426327502p+0),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.log1p_64() special" {
    const cases = test_utils.genTests(Tc64, special_tests) ++ test_utils.nanTests(Tc64);
    try runTests(cases);
}

test "math.log1p_64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64( 0x1.fffffffffffffp+1023,  0x1.62e42fefa39efp+9), // Max input value
        tc64( 0x1p-1074,                0x1p-1074           ), // Min positive input value
        tc64(-0x1p-1074,               -0x1p-1074           ), // Min negative input value
        tc64( 0x1p-1022,                0x1p-1022           ), // First subnormal
        tc64(-0x1p-1022,               -0x1p-1022           ), // First negative subnormal
        tc64(-0x1.fffffffffffffp-1,    -0x1.25e4f7b2737fap+5), // Last value before result is -inf
        tc64(-0x1.0000000000001p+0,     nan64               ), // First value where result is nan
        // zig fmt: on
    };
    try runTests(cases);
}

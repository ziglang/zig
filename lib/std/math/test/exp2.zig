const math = @import("../../math.zig");
const test_utils = @import("../test.zig");
const Testcase = test_utils.Testcase;
const runTests = test_utils.runTests;
const floatFromBits = test_utils.floatFromBits;
const negInf = test_utils.negInf;
const inf32 = math.inf_f32;
const inf64 = math.inf_f64;

const Tc32 = Testcase(math.exp2, "exp2", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.exp2, "exp2", f64);
const tc64 = Tc64.init;

// Special-case tests shared between different float sizes, see genTests().
const special_tests = .{
    // zig fmt: off
    .{ 0,        1       },
    .{-0,        1       },
    .{ 1,        2       },
    .{-1,        0.5     },
    .{ math.inf, math.inf},
    .{ negInf,   0       },
    // zig fmt: on
};

test "math.exp2_32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3, 0x1.e8d134p-9),
        tc32( 0x1.161868p+2, 0x1.453672p+4),
        tc32(-0x1.0c34b4p+3, 0x1.890ca0p-9),
        tc32(-0x1.a206f0p+2, 0x1.622d4ep-7),
        tc32( 0x1.288bbcp+3, 0x1.340ecep+9),
        tc32( 0x1.52efd0p-1, 0x1.950eeep+0),
        tc32(-0x1.a05cc8p-2, 0x1.824056p-1),
        tc32( 0x1.1f9efap-1, 0x1.79dfa2p+0),
        tc32( 0x1.8c5db0p-1, 0x1.b5ceacp+0),
        tc32(-0x1.5b86eap-1, 0x1.3fd8bap-1),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.exp2_32() special" {
    const cases = test_utils.genTests(Tc32, special_tests) ++ test_utils.nanTests(Tc32);
    try runTests(cases);
}

test "math.exp2_32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32( 0x1.fffffep+6,   0x1.ffff4ep+127), // The last value before the result gets infinite
        tc32( 0x1p+7,          inf32          ), // The first value that gives infinite result
        tc32(-0x1.2bccccp+7,   0x1p-149       ), // The last value before the result flushes to zero
        tc32(-0x1.2cp+7,       0              ), // The first value at which the result flushes to zero
        tc32(-0x1.f8p+6,       0x1p-126       ), // The last value before the result flushes to subnormal
        tc32(-0x1.f80002p+6,   0x1.ffff50p-127), // The first value for which the result flushes to subnormal
        tc32( 0x1.fffffep+127, inf32          ), // Max input value
        tc32( 0x1p-149,        1              ), // Min positive input value
        tc32(-0x1p-149,        1              ), // Min negative input value
        tc32( 0x1p-126,        1              ), // First positive subnormal input
        tc32(-0x1p-126,        1              ), // First negative subnormal input
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.exp2_64() sanity" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3, 0x1.e8d13c396f452p-9),
        tc64( 0x1.161868e18bc67p+2, 0x1.4536746bb6f12p+4),
        tc64(-0x1.0c34b3e01e6e7p+3, 0x1.890ca0c00b9a2p-9),
        tc64(-0x1.a206f0a19dcc4p+2, 0x1.622d4b0ebc6c1p-7),
        tc64( 0x1.288bbb0d6a1e6p+3, 0x1.340ec7f3e607ep+9),
        tc64( 0x1.52efd0cd80497p-1, 0x1.950eef4bc5451p+0),
        tc64(-0x1.a05cc754481d1p-2, 0x1.824056efc687cp-1),
        tc64( 0x1.1f9ef934745cbp-1, 0x1.79dfa14ab121ep+0),
        tc64( 0x1.8c5db097f7442p-1, 0x1.b5cead2247372p+0),
        tc64(-0x1.5b86ea8118a0ep-1, 0x1.3fd8ba33216b9p-1),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.exp2_64() special" {
    const cases = test_utils.genTests(Tc64, special_tests) ++ test_utils.nanTests(Tc64);
    try runTests(cases);
}

test "math.exp2_64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64( 0x1.fffffffffffffp+9,    0x1.ffffffffffd3ap+1023), // The last value before the result gets infinite
        tc64( 0x1p+10,                 inf64                  ), // The first value that gives infinite result
        tc64(-0x1.0cbffffffffffp+10,   0x1p-1074              ), // The last value before the result flushes to zero
        tc64(-0x1.0ccp+10,             0                      ), // The first value at which the result flushes to zero
        tc64(-0x1.ffp+9,               0x1p-1022              ), // The last value before the result flushes to subnormal
        tc64(-0x1.ff00000000001p+9,    0x1.ffffffffffd3ap-1023), // The first value for which the result flushes to subnormal
        tc64( 0x1.fffffffffffffp+1023, inf64                  ), // Max input value
        tc64( 0x1p-1074,               1                      ), // Min positive input value
        tc64(-0x1p-1074,               1                      ), // Min negative input value
        tc64( 0x1p-1022,               1                      ), // First positive subnormal input
        tc64(-0x1p-1022,               1                      ), // First negative subnormal input
        // zig fmt: on
    };
    try runTests(cases);
}

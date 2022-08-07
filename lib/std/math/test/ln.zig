const math = @import("../../math.zig");
const test_utils = @import("../test.zig");
const Testcase = test_utils.Testcase;
const runTests = test_utils.runTests;
const floatFromBits = test_utils.floatFromBits;
const negInf = test_utils.negInf;
const nan32 = math.nan_f32;
const nan64 = math.nan_f64;

const Tc32 = Testcase(math.ln, "ln", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.ln, "ln", f64);
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
    .{ math.e,    1       },
    .{ 2,         math.ln2},
    .{-1,         math.nan},
    .{ math.inf,  math.inf},
    .{ negInf,    math.nan},
    // zig fmt: on
};

test "math.ln32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3,  nan32        ),
        tc32( 0x1.161868p+2,  0x1.7815b0p+0),
        tc32(-0x1.0c34b4p+3,  nan32        ),
        tc32(-0x1.a206f0p+2,  nan32        ),
        tc32( 0x1.288bbcp+3,  0x1.1cfcd6p+1),
        tc32( 0x1.52efd0p-1, -0x1.a6694cp-2),
        tc32(-0x1.a05cc8p-2,  nan32        ),
        tc32( 0x1.1f9efap-1, -0x1.2742bap-1),
        tc32( 0x1.8c5db0p-1, -0x1.062160p-2),
        tc32(-0x1.5b86eap-1,  nan32        ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.ln32() special" {
    const cases = test_utils.genTests(Tc32, special_tests) ++ test_utils.nanTests(Tc32);
    try runTests(cases);
}

test "math.ln32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32( 0x1.fffffep+127,  0x1.62e430p+6 ), // Max input value
        tc32( 0x1p-149,        -0x1.9d1da0p+6 ), // Min positive input value
        tc32(-0x1p-149,         nan32         ), // Min negative input value
        tc32( 0x1.000002p+0,    0x1.fffffep-24), // Last value before result reaches +0
        tc32( 0x1.fffffep-1,   -0x1p-24       ), // Last value before result reaches -0
        tc32( 0x1p-126,        -0x1.5d58a0p+6 ), // First subnormal
        tc32(-0x1p-126,         nan32         ), // First negative subnormal
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.ln64() sanity" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3,  nan64               ),
        tc64( 0x1.161868e18bc67p+2,  0x1.7815b08f99c65p+0),
        tc64(-0x1.0c34b3e01e6e7p+3,  nan64               ),
        tc64(-0x1.a206f0a19dcc4p+2,  nan64               ),
        tc64( 0x1.288bbb0d6a1e6p+3,  0x1.1cfcd53d72604p+1),
        tc64( 0x1.52efd0cd80497p-1, -0x1.a6694a4a85621p-2),
        tc64(-0x1.a05cc754481d1p-2,  nan64               ),
        tc64( 0x1.1f9ef934745cbp-1, -0x1.2742bc03d02ddp-1),
        tc64( 0x1.8c5db097f7442p-1, -0x1.06215de4a3f92p-2),
        tc64(-0x1.5b86ea8118a0ep-1,  nan64               ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.ln64() special" {
    const cases = test_utils.genTests(Tc64, special_tests) ++ test_utils.nanTests(Tc64);
    try runTests(cases);
}

test "math.ln64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64( 0x1.fffffffffffffp+1023,  0x1.62e42fefa39efp+9 ), // Max input value
        tc64( 0x1p-1074,               -0x1.74385446d71c3p+9 ), // Min positive input value
        tc64(-0x1p-1074,                nan64                ), // Min negative input value
        tc64( 0x1.0000000000001p+0,     0x1.fffffffffffffp-53), // Last value before result reaches +0
        tc64( 0x1.fffffffffffffp-1,    -0x1p-53              ), // Last value before result reaches -0
        tc64( 0x1p-1022,               -0x1.6232bdd7abcd2p+9 ), // First subnormal
        tc64(-0x1p-1022,                nan64                ), // First negative subnormal
        // zig fmt: on
    };
    try runTests(cases);
}

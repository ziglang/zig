const math = @import("../../math.zig");
const test_utils = @import("../test.zig");
const Testcase = test_utils.Testcase;
const runTests = test_utils.runTests;
const floatFromBits = test_utils.floatFromBits;
const negInf = test_utils.negInf;
const inf32 = math.inf_f32;
const inf64 = math.inf_f64;

const Tc32 = Testcase(math.expo2, "expo2", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.expo2, "expo2", f64);
const tc64 = Tc64.init;

// Special-case tests shared between different float sizes, see genTests().
const special_tests = .{
    // zig fmt: off
    .{ 0,        0.5     },
    .{-0,        0.5     },
    .{ math.ln2, 1       },
    .{ math.inf, math.inf},
    .{ negInf,   0       },
    // zig fmt: on
};

test "math.expo2_32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3, 0x1.490320p-13),
        tc32( 0x1.161868p+2, 0x1.34712ap+5 ),
        tc32(-0x1.0c34b4p+3, 0x1.e06b1ap-14),
        tc32(-0x1.a206f0p+2, 0x1.7dd484p-11),
        tc32( 0x1.288bbcp+3, 0x1.4abc80p+12),
        tc32( 0x1.52efd0p-1, 0x1.f04a9cp-1 ),
        tc32(-0x1.a05cc8p-2, 0x1.54f1e0p-2 ),
        tc32( 0x1.1f9efap-1, 0x1.c0f628p-1 ),
        tc32( 0x1.8c5db0p-1, 0x1.1599b2p+0 ),
        tc32(-0x1.5b86eap-1, 0x1.03b572p-2 ),
        tc32(-0x1.57f25cp+2, 0x1.2fbea2p-9 ),
        tc32( 0x1.c7d310p+3, 0x1.76eefp+19 ),
        tc32( 0x1.19be70p+4, 0x1.52d3dep+24),
        tc32(-0x1.ab6d70p+3, 0x1.a88adep-21),
        tc32(-0x1.5ac18ep+2, 0x1.22b328p-9 ),
        tc32(-0x1.925982p-1, 0x1.d2acc0p-3 ),
        tc32( 0x1.7221cep+3, 0x1.9c2ceap+15),
        tc32( 0x1.11a0d4p+4, 0x1.980ee6p+23),
        tc32(-0x1.ae41a2p+1, 0x1.1c28d0p-6 ),
        tc32(-0x1.329154p+4, 0x1.47ef94p-29),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expo2_32() special" {
    const cases = test_utils.genTests(Tc32, special_tests) ++ test_utils.nanTests(Tc32);
    try runTests(cases);
}

test "math.expo2_32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        // TODO
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expo2_64() sanity" {
    const cases = [_]Tc64{
        // zig fmt: off
        tc64(-0x1.02239f3c6a8f1p+3, 0x1.490327ea61235p-13),
        tc64( 0x1.161868e18bc67p+2, 0x1.34712ed238c04p+5 ),
        tc64(-0x1.0c34b3e01e6e7p+3, 0x1.e06b1b6c18e64p-14),
        tc64(-0x1.a206f0a19dcc4p+2, 0x1.7dd47f810e68cp-11),
        tc64( 0x1.288bbb0d6a1e6p+3, 0x1.4abc77496e07ep+12),
        tc64( 0x1.52efd0cd80497p-1, 0x1.f04a9c1080500p-1 ),
        tc64(-0x1.a05cc754481d1p-2, 0x1.54f1e0fd3ea0dp-2 ),
        tc64( 0x1.1f9ef934745cbp-1, 0x1.c0f6266a6a547p-1 ),
        tc64( 0x1.8c5db097f7442p-1, 0x1.1599b1d4a25fbp+0 ),
        tc64(-0x1.5b86ea8118a0ep-1, 0x1.03b5728a00229p-2 ),
        tc64(-0x1.57f25b2b5006dp+2, 0x1.2fbea6a01cab9p-9 ),
        tc64( 0x1.c7d30fb825911p+3, 0x1.76eeed45a0634p+19),
        tc64( 0x1.19be709de7505p+4, 0x1.52d3eb7be6844p+24),
        tc64(-0x1.ab6d6fba96889p+3, 0x1.a88ae12f985d6p-21),
        tc64(-0x1.5ac18e27084ddp+2, 0x1.22b327da9cca6p-9 ),
        tc64(-0x1.925981b093c41p-1, 0x1.d2acc046b55f7p-3 ),
        tc64( 0x1.7221cd18455f5p+3, 0x1.9c2cde8699cfbp+15),
        tc64( 0x1.11a0d4a51b239p+4, 0x1.980ef612ff182p+23),
        tc64(-0x1.ae41a1079de4dp+1, 0x1.1c28d16bb3222p-6 ),
        tc64(-0x1.329153103b871p+4, 0x1.47efa6ddd0d22p-29),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expo2_64() special" {
    const cases = test_utils.genTests(Tc64, special_tests) ++ test_utils.nanTests(Tc64);
    try runTests(cases);
}

test "math.expo2_64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        // TODO
        // zig fmt: on
    };
    try runTests(cases);
}

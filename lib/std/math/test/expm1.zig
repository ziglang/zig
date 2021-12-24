const math = @import("../../math.zig");
const Testcase = @import("../test.zig").Testcase;
const runTests = @import("../test.zig").runTests;
const floatFromBits = @import("../test.zig").floatFromBits;
const inf32 = math.inf_f32;
const inf64 = math.inf_f64;
const nan32 = math.nan_f32;
const nan64 = math.nan_f64;

const Tc32 = Testcase(math.expm1, "expm1", f32);
const tc32 = Tc32.init;

const Tc64 = Testcase(math.expm1, "expm1", f64);
const tc64 = Tc64.init;

test "math.expm1_32() sanity" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32(-0x1.0223a0p+3, -0x1.ffd6e0p-1 ),
        tc32( 0x1.161868p+2,  0x1.30712ap+6 ),
        tc32(-0x1.0c34b4p+3, -0x1.ffe1fap-1 ),
        tc32(-0x1.a206f0p+2, -0x1.ff4116p-1 ),
        // TODO: Error in last digit
        // tc32( 0x1.288bbcp+3,  0x1.4ab482p+13),
        tc32( 0x1.52efd0p-1,  0x1.e09536p-1 ),
        // TODO:  Giving   ->   -0x1.561becp-2
        // tc32(-0x1.a05cc8p-2, -0x1.561c3ep-2 ),
        tc32( 0x1.1f9efap-1,  0x1.81ec4ep-1 ),
        tc32( 0x1.8c5db0p-1,  0x1.2b3364p+0 ),
        // TODO:  Giving   ->   -0x1.f8933p-2
        // tc32(-0x1.5b86eap-1, -0x1.f8951ap-2 ),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expm1_32() special" {
    const cases = [_]Tc32{
        // zig fmt: off
        tc32( 0,      0     ),
        tc32(-0,      0     ),
        tc32( inf32,  inf32 ),
        tc32(-inf32, -1     ),
        // NaNs: should be unchanged when passed through.
        tc32( nan32,  nan32 ),
        tc32(-nan32, -nan32 ),
        tc32(floatFromBits(f32, 0x7ff01234), floatFromBits(f32, 0x7ff01234)),
        tc32(floatFromBits(f32, 0xfff01234), floatFromBits(f32, 0xfff01234)),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expm1_32() boundary" {
    const cases = [_]Tc32{
        // zig fmt: off
        // TODO
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
    const cases = [_]Tc64{
        // zig fmt: off
        tc64( 0,      0    ),
        tc64(-0,      0    ),
        tc64( inf64,  inf64),
        tc64(-inf64, -1    ),
        // NaNs: should be unchanged when passed through.
        tc64( nan64,  nan64 ),
        tc64(-nan64, -nan64 ),
        tc64(floatFromBits(f64, 0x7ff0123400000000), floatFromBits(f64, 0x7ff0123400000000)),
        tc64(floatFromBits(f64, 0xfff0123400000000), floatFromBits(f64, 0xfff0123400000000)),
        // zig fmt: on
    };
    try runTests(cases);
}

test "math.expm1_64() boundary" {
    const cases = [_]Tc64{
        // zig fmt: off
        // TODO
        // zig fmt: on
    };
    try runTests(cases);
}

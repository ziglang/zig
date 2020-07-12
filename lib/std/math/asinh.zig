// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/asinhf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/asinh.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns the hyperbolic arc-sin of x.
///
/// Special Cases:
///  - asinh(+-0)   = +-0
///  - asinh(+-inf) = +-inf
///  - asinh(nan)   = nan
pub fn asinh(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => asinh32(x),
        f64 => asinh64(x),
        else => @compileError("asinh not implemented for " ++ @typeName(T)),
    };
}

// asinh(x) = sign(x) * log(|x| + sqrt(x * x + 1)) ~= x - x^3/6 + o(x^5)
fn asinh32(x: f32) f32 {
    const u = @bitCast(u32, x);
    const i = u & 0x7FFFFFFF;
    const s = i >> 31;

    var rx = @bitCast(f32, i); // |x|

    // TODO: Shouldn't need this explicit check.
    if (math.isNegativeInf(x)) {
        return x;
    }

    // |x| >= 0x1p12 or inf or nan
    if (i >= 0x3F800000 + (12 << 23)) {
        rx = math.ln(rx) + 0.69314718055994530941723212145817656;
    }
    // |x| >= 2
    else if (i >= 0x3F800000 + (1 << 23)) {
        rx = math.ln(2 * x + 1 / (math.sqrt(x * x + 1) + x));
    }
    // |x| >= 0x1p-12, up to 1.6ulp error
    else if (i >= 0x3F800000 - (12 << 23)) {
        rx = math.log1p(x + x * x / (math.sqrt(x * x + 1) + 1));
    }
    // |x| < 0x1p-12, inexact if x != 0
    else {
        math.forceEval(x + 0x1.0p120);
    }

    return if (s != 0) -rx else rx;
}

fn asinh64(x: f64) f64 {
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    const s = u >> 63;

    var rx = @bitCast(f64, u & (maxInt(u64) >> 1)); // |x|

    if (math.isNegativeInf(x)) {
        return x;
    }

    // |x| >= 0x1p26 or inf or nan
    if (e >= 0x3FF + 26) {
        rx = math.ln(rx) + 0.693147180559945309417232121458176568;
    }
    // |x| >= 2
    else if (e >= 0x3FF + 1) {
        rx = math.ln(2 * x + 1 / (math.sqrt(x * x + 1) + x));
    }
    // |x| >= 0x1p-12, up to 1.6ulp error
    else if (e >= 0x3FF - 26) {
        rx = math.log1p(x + x * x / (math.sqrt(x * x + 1) + 1));
    }
    // |x| < 0x1p-12, inexact if x != 0
    else {
        math.forceEval(x + 0x1.0p120);
    }

    return if (s != 0) -rx else rx;
}

test "math.asinh" {
    expect(asinh(@as(f32, 0.0)) == asinh32(0.0));
    expect(asinh(@as(f64, 0.0)) == asinh64(0.0));
}

test "math.asinh32" {
    const epsilon = 0.000001;

    expect(math.approxEq(f32, asinh32(0.0), 0.0, epsilon));
    expect(math.approxEq(f32, asinh32(0.2), 0.198690, epsilon));
    expect(math.approxEq(f32, asinh32(0.8923), 0.803133, epsilon));
    expect(math.approxEq(f32, asinh32(1.5), 1.194763, epsilon));
    expect(math.approxEq(f32, asinh32(37.45), 4.316332, epsilon));
    expect(math.approxEq(f32, asinh32(89.123), 5.183196, epsilon));
    expect(math.approxEq(f32, asinh32(123123.234375), 12.414088, epsilon));
}

test "math.asinh64" {
    const epsilon = 0.000001;

    expect(math.approxEq(f64, asinh64(0.0), 0.0, epsilon));
    expect(math.approxEq(f64, asinh64(0.2), 0.198690, epsilon));
    expect(math.approxEq(f64, asinh64(0.8923), 0.803133, epsilon));
    expect(math.approxEq(f64, asinh64(1.5), 1.194763, epsilon));
    expect(math.approxEq(f64, asinh64(37.45), 4.316332, epsilon));
    expect(math.approxEq(f64, asinh64(89.123), 5.183196, epsilon));
    expect(math.approxEq(f64, asinh64(123123.234375), 12.414088, epsilon));
}

test "math.asinh32.special" {
    expect(asinh32(0.0) == 0.0);
    expect(asinh32(-0.0) == -0.0);
    expect(math.isPositiveInf(asinh32(math.inf(f32))));
    expect(math.isNegativeInf(asinh32(-math.inf(f32))));
    expect(math.isNan(asinh32(math.nan(f32))));
}

test "math.asinh64.special" {
    expect(asinh64(0.0) == 0.0);
    expect(asinh64(-0.0) == -0.0);
    expect(math.isPositiveInf(asinh64(math.inf(f64))));
    expect(math.isNegativeInf(asinh64(-math.inf(f64))));
    expect(math.isNan(asinh64(math.nan(f64))));
}

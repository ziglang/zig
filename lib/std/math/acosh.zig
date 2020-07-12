// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/acoshf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/acosh.c

const builtin = @import("builtin");
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the hyperbolic arc-cosine of x.
///
/// Special cases:
///  - acosh(x)   = snan if x < 1
///  - acosh(nan) = nan
pub fn acosh(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => acosh32(x),
        f64 => acosh64(x),
        else => @compileError("acosh not implemented for " ++ @typeName(T)),
    };
}

// acosh(x) = log(x + sqrt(x * x - 1))
fn acosh32(x: f32) f32 {
    const u = @bitCast(u32, x);
    const i = u & 0x7FFFFFFF;

    // |x| < 2, invalid if x < 1 or nan
    if (i < 0x3F800000 + (1 << 23)) {
        return math.log1p(x - 1 + math.sqrt((x - 1) * (x - 1) + 2 * (x - 1)));
    }
    // |x| < 0x1p12
    else if (i < 0x3F800000 + (12 << 23)) {
        return math.ln(2 * x - 1 / (x + math.sqrt(x * x - 1)));
    }
    // |x| >= 0x1p12
    else {
        return math.ln(x) + 0.693147180559945309417232121458176568;
    }
}

fn acosh64(x: f64) f64 {
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;

    // |x| < 2, invalid if x < 1 or nan
    if (e < 0x3FF + 1) {
        return math.log1p(x - 1 + math.sqrt((x - 1) * (x - 1) + 2 * (x - 1)));
    }
    // |x| < 0x1p26
    else if (e < 0x3FF + 26) {
        return math.ln(2 * x - 1 / (x + math.sqrt(x * x - 1)));
    }
    // |x| >= 0x1p26 or nan
    else {
        return math.ln(x) + 0.693147180559945309417232121458176568;
    }
}

test "math.acosh" {
    expect(acosh(@as(f32, 1.5)) == acosh32(1.5));
    expect(acosh(@as(f64, 1.5)) == acosh64(1.5));
}

test "math.acosh32" {
    const epsilon = 0.000001;

    expect(math.approxEq(f32, acosh32(1.5), 0.962424, epsilon));
    expect(math.approxEq(f32, acosh32(37.45), 4.315976, epsilon));
    expect(math.approxEq(f32, acosh32(89.123), 5.183133, epsilon));
    expect(math.approxEq(f32, acosh32(123123.234375), 12.414088, epsilon));
}

test "math.acosh64" {
    const epsilon = 0.000001;

    expect(math.approxEq(f64, acosh64(1.5), 0.962424, epsilon));
    expect(math.approxEq(f64, acosh64(37.45), 4.315976, epsilon));
    expect(math.approxEq(f64, acosh64(89.123), 5.183133, epsilon));
    expect(math.approxEq(f64, acosh64(123123.234375), 12.414088, epsilon));
}

test "math.acosh32.special" {
    expect(math.isNan(acosh32(math.nan(f32))));
    expect(math.isSignalNan(acosh32(0.5)));
}

test "math.acosh64.special" {
    expect(math.isNan(acosh64(math.nan(f64))));
    expect(math.isSignalNan(acosh64(0.5)));
}

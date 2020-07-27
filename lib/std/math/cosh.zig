// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/coshf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/cosh.c

const builtin = @import("builtin");
const std = @import("../std.zig");
const math = std.math;
const expo2 = @import("expo2.zig").expo2;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns the hyperbolic cosine of x.
///
/// Special Cases:
///  - cosh(+-0)   = 1
///  - cosh(+-inf) = +inf
///  - cosh(nan)   = nan
pub fn cosh(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => cosh32(x),
        f64 => cosh64(x),
        else => @compileError("cosh not implemented for " ++ @typeName(T)),
    };
}

// cosh(x) = (exp(x) + 1 / exp(x)) / 2
//         = 1 + 0.5 * (exp(x) - 1) * (exp(x) - 1) / exp(x)
//         = 1 + (x * x) / 2 + o(x^4)
fn cosh32(x: f32) f32 {
    const u = @bitCast(u32, x);
    const ux = u & 0x7FFFFFFF;
    const ax = @bitCast(f32, ux);

    // |x| < log(2)
    if (ux < 0x3F317217) {
        if (ux < 0x3F800000 - (12 << 23)) {
            math.raiseOverflow();
            return 1.0;
        }
        const t = math.expm1(ax);
        return 1 + t * t / (2 * (1 + t));
    }

    // |x| < log(FLT_MAX)
    if (ux < 0x42B17217) {
        const t = math.exp(ax);
        return 0.5 * (t + 1 / t);
    }

    // |x| > log(FLT_MAX) or nan
    return expo2(ax);
}

fn cosh64(x: f64) f64 {
    const u = @bitCast(u64, x);
    const w = @intCast(u32, u >> 32) & (maxInt(u32) >> 1);
    const ax = @bitCast(f64, u & (maxInt(u64) >> 1));

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return 1.0;
    }

    // |x| < log(2)
    if (w < 0x3FE62E42) {
        if (w < 0x3FF00000 - (26 << 20)) {
            if (x != 0) {
                math.raiseInexact();
            }
            return 1.0;
        }
        const t = math.expm1(ax);
        return 1 + t * t / (2 * (1 + t));
    }

    // |x| < log(DBL_MAX)
    if (w < 0x40862E42) {
        const t = math.exp(ax);
        // NOTE: If x > log(0x1p26) then 1/t is not required.
        return 0.5 * (t + 1 / t);
    }

    // |x| > log(CBL_MAX) or nan
    return expo2(ax);
}

test "math.cosh" {
    expect(cosh(@as(f32, 1.5)) == cosh32(1.5));
    expect(cosh(@as(f64, 1.5)) == cosh64(1.5));
}

test "math.cosh32" {
    const epsilon = 0.000001;

    expect(math.approxEq(f32, cosh32(0.0), 1.0, epsilon));
    expect(math.approxEq(f32, cosh32(0.2), 1.020067, epsilon));
    expect(math.approxEq(f32, cosh32(0.8923), 1.425225, epsilon));
    expect(math.approxEq(f32, cosh32(1.5), 2.352410, epsilon));
    expect(math.approxEq(f32, cosh32(-0.0), 1.0, epsilon));
    expect(math.approxEq(f32, cosh32(-0.2), 1.020067, epsilon));
    expect(math.approxEq(f32, cosh32(-0.8923), 1.425225, epsilon));
    expect(math.approxEq(f32, cosh32(-1.5), 2.352410, epsilon));
}

test "math.cosh64" {
    const epsilon = 0.000001;

    expect(math.approxEq(f64, cosh64(0.0), 1.0, epsilon));
    expect(math.approxEq(f64, cosh64(0.2), 1.020067, epsilon));
    expect(math.approxEq(f64, cosh64(0.8923), 1.425225, epsilon));
    expect(math.approxEq(f64, cosh64(1.5), 2.352410, epsilon));
    expect(math.approxEq(f64, cosh64(-0.0), 1.0, epsilon));
    expect(math.approxEq(f64, cosh64(-0.2), 1.020067, epsilon));
    expect(math.approxEq(f64, cosh64(-0.8923), 1.425225, epsilon));
    expect(math.approxEq(f64, cosh64(-1.5), 2.352410, epsilon));
}

test "math.cosh32.special" {
    expect(cosh32(0.0) == 1.0);
    expect(cosh32(-0.0) == 1.0);
    expect(math.isPositiveInf(cosh32(math.inf(f32))));
    expect(math.isPositiveInf(cosh32(-math.inf(f32))));
    expect(math.isNan(cosh32(math.nan(f32))));
}

test "math.cosh64.special" {
    expect(cosh64(0.0) == 1.0);
    expect(cosh64(-0.0) == 1.0);
    expect(math.isPositiveInf(cosh64(math.inf(f64))));
    expect(math.isPositiveInf(cosh64(-math.inf(f64))));
    expect(math.isNan(cosh64(math.nan(f64))));
}

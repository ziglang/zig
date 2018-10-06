// Special Cases:
//
//  powf(x, +-0)    = 1 for any x
//  powf(1, y)      = 1 for any y
//  powf(x, 1)      = x for any x
//  powf(nan, y)    = nan
//  powf(x, nan)    = nan
//  powf(+-0, y)    = +-inf for y an odd integer < 0
//  powf(+-0, -inf) = +inf
//  powf(+-0, +inf) = +0
//  powf(+-0, y)    = +inf for finite y < 0 and not an odd integer
//  powf(+-0, y)    = +-0 for y an odd integer > 0
//  powf(+-0, y)    = +0 for finite y > 0 and not an odd integer
//  powf(-1, +-inf) = 1
//  powf(x, +inf)   = +inf for |x| > 1
//  powf(x, -inf)   = +0 for |x| > 1
//  powf(x, +inf)   = +0 for |x| < 1
//  powf(x, -inf)   = +inf for |x| < 1
//  powf(+inf, y)   = +inf for y > 0
//  powf(+inf, y)   = +0 for y < 0
//  powf(-inf, y)   = powf(-0, -y)
//  powf(x, y)      = nan for finite x < 0 and finite non-integer y

const builtin = @import("builtin");
const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

// This implementation is taken from the go stlib, musl is a bit more complex.
pub fn powf(comptime T: type, x: T, y: T) T {
    if (T != f32 and T != f64) {
        @compileError("powf not implemented for " ++ @typeName(T));
    }

    // powf(x, +-0) = 1      for all x
    // powf(1, y) = 1        for all y
    if (y == 0 or x == 1) {
        return 1;
    }

    // powf(nan, y) = nan    for all y
    // powf(x, nan) = nan    for all x
    if (math.isNan(x) or math.isNan(y)) {
        return math.nan(T);
    }

    // powf(x, 1) = x        for all x
    if (y == 1) {
        return x;
    }

    // special case sqrt
    if (y == 0.5) {
        return math.sqrt(x);
    }

    if (y == -0.5) {
        return 1 / math.sqrt(x);
    }

    if (x == 0) {
        if (y < 0) {
            // powf(+-0, y) = +- 0   for y an odd integer
            if (isOddInteger(y)) {
                return math.copysign(T, math.inf(T), x);
            }
            // powf(+-0, y) = +inf   for y an even integer
            else {
                return math.inf(T);
            }
        } else {
            if (isOddInteger(y)) {
                return x;
            } else {
                return 0;
            }
        }
    }

    if (math.isInf(y)) {
        // powf(-1, inf) = 1     for all x
        if (x == -1) {
            return 1.0;
        }
        // powf(x, +inf) = +0    for |x| < 1
        // powf(x, -inf) = +0    for |x| > 1
        else if ((math.fabs(x) < 1) == math.isPositiveInf(y)) {
            return 0;
        }
        // powf(x, -inf) = +inf  for |x| < 1
        // powf(x, +inf) = +inf  for |x| > 1
        else {
            return math.inf(T);
        }
    }

    if (math.isInf(x)) {
        if (math.isNegativeInf(x)) {
            return powf(T, 1 / x, -y);
        }
        // powf(+inf, y) = +0    for y < 0
        else if (y < 0) {
            return 0;
        }
        // powf(+inf, y) = +0    for y > 0
        else if (y > 0) {
            return math.inf(T);
        }
    }

    var ay = y;
    var flip = false;
    if (ay < 0) {
        ay = -ay;
        flip = true;
    }

    const r1 = math.modf(ay);
    var yi = r1.ipart;
    var yf = r1.fpart;

    if (yf != 0 and x < 0) {
        return math.nan(T);
    }
    if (yi >= 1 << (T.bit_count - 1)) {
        return math.exp(y * math.ln(x));
    }

    // a = a1 * 2^ae
    var a1: T = 1.0;
    var ae: i32 = 0;

    // a *= x^yf
    if (yf != 0) {
        if (yf > 0.5) {
            yf -= 1;
            yi += 1;
        }
        a1 = math.exp(yf * math.ln(x));
    }

    // a *= x^yi
    const r2 = math.frexp(x);
    var xe = r2.exponent;
    var x1 = r2.significand;

    var i = @floatToInt(i32, yi);
    while (i != 0) : (i >>= 1) {
        if (i & 1 == 1) {
            a1 *= x1;
            ae += xe;
        }
        x1 *= x1;
        xe <<= 1;
        if (x1 < 0.5) {
            x1 += x1;
            xe -= 1;
        }
    }

    // a *= a1 * 2^ae
    if (flip) {
        a1 = 1 / a1;
        ae = -ae;
    }

    return math.scalbn(a1, ae);
}

fn isOddInteger(x: f64) bool {
    const r = math.modf(x);
    return r.fpart == 0.0 and @floatToInt(i64, r.ipart) & 1 == 1;
}

test "math.powf" {
    const epsilon = 0.000001;

    assert(math.approxEq(f32, powf(f32, 0.0, 3.3), 0.0, epsilon));
    assert(math.approxEq(f32, powf(f32, 0.8923, 3.3), 0.686572, epsilon));
    assert(math.approxEq(f32, powf(f32, 0.2, 3.3), 0.004936, epsilon));
    assert(math.approxEq(f32, powf(f32, 1.5, 3.3), 3.811546, epsilon));
    assert(math.approxEq(f32, powf(f32, 37.45, 3.3), 155736.703125, epsilon));
    assert(math.approxEq(f32, powf(f32, 89.123, 3.3), 2722489.5, epsilon));

    assert(math.approxEq(f64, powf(f64, 0.0, 3.3), 0.0, epsilon));
    assert(math.approxEq(f64, powf(f64, 0.8923, 3.3), 0.686572, epsilon));
    assert(math.approxEq(f64, powf(f64, 0.2, 3.3), 0.004936, epsilon));
    assert(math.approxEq(f64, powf(f64, 1.5, 3.3), 3.811546, epsilon));
    assert(math.approxEq(f64, powf(f64, 37.45, 3.3), 155736.7160616, epsilon));
    assert(math.approxEq(f64, powf(f64, 89.123, 3.3), 2722490.231436, epsilon));
}

test "math.powf.special" {
    const epsilon = 0.000001;

    assert(powf(f32, 4, 0.0) == 1.0);
    assert(powf(f32, 7, -0.0) == 1.0);
    assert(powf(f32, 45, 1.0) == 45);
    assert(powf(f32, -45, 1.0) == -45);
    assert(math.isNan(powf(f32, math.nan(f32), 5.0)));
    assert(math.isNan(powf(f32, 5.0, math.nan(f32))));
    assert(math.isPositiveInf(powf(f32, 0.0, -1.0)));
    //assert(math.isNegativeInf(powf(f32, -0.0, -3.0))); TODO is this required?
    assert(math.isPositiveInf(powf(f32, 0.0, -math.inf(f32))));
    assert(math.isPositiveInf(powf(f32, -0.0, -math.inf(f32))));
    assert(powf(f32, 0.0, math.inf(f32)) == 0.0);
    assert(powf(f32, -0.0, math.inf(f32)) == 0.0);
    assert(math.isPositiveInf(powf(f32, 0.0, -2.0)));
    assert(math.isPositiveInf(powf(f32, -0.0, -2.0)));
    assert(powf(f32, 0.0, 1.0) == 0.0);
    assert(powf(f32, -0.0, 1.0) == -0.0);
    assert(powf(f32, 0.0, 2.0) == 0.0);
    assert(powf(f32, -0.0, 2.0) == 0.0);
    assert(math.approxEq(f32, powf(f32, -1.0, math.inf(f32)), 1.0, epsilon));
    assert(math.approxEq(f32, powf(f32, -1.0, -math.inf(f32)), 1.0, epsilon));
    assert(math.isPositiveInf(powf(f32, 1.2, math.inf(f32))));
    assert(math.isPositiveInf(powf(f32, -1.2, math.inf(f32))));
    assert(powf(f32, 1.2, -math.inf(f32)) == 0.0);
    assert(powf(f32, -1.2, -math.inf(f32)) == 0.0);
    assert(powf(f32, 0.2, math.inf(f32)) == 0.0);
    assert(powf(f32, -0.2, math.inf(f32)) == 0.0);
    assert(math.isPositiveInf(powf(f32, 0.2, -math.inf(f32))));
    assert(math.isPositiveInf(powf(f32, -0.2, -math.inf(f32))));
    assert(math.isPositiveInf(powf(f32, math.inf(f32), 1.0)));
    assert(powf(f32, math.inf(f32), -1.0) == 0.0);
    //assert(powf(f32, -math.inf(f32), 5.0) == powf(f32, -0.0, -5.0)); TODO support negative 0?
    assert(powf(f32, -math.inf(f32), -5.2) == powf(f32, -0.0, 5.2));
    assert(math.isNan(powf(f32, -1.0, 1.2)));
    assert(math.isNan(powf(f32, -12.4, 78.5)));
}

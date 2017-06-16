const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn pow(comptime T: type, x: T, y: T) -> T {
    switch (T) {
        f32 => @inlineCall(pow32, x, y),
        f64 => @inlineCall(pow64, x, y),
        else => @compileError("pow not implemented for " ++ @typeName(T)),
    }
}

fn isOddInteger(x: f64) -> bool {
    const r = math.modf(x);
    r.fpart == 0.0 and i64(r.ipart) & 1 == 1
}

// This implementation is taken from the go stlib, musl is a bit more complex.
fn pow32(x: f32, y: f32) -> f32 {
    // pow(x, +-0) = 1      for all x
    // pow(1, y) = 1        for all y
    if (y == 0 or x == 1) {
        return 1;
    }

    // pow(nan, y) = nan    for all y
    // pow(x, nan) = nan    for all x
    if (math.isNan(x) or math.isNan(y)) {
        return math.nan(f32);
    }

    // pow(x, 1) = x        for all x
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
            // pow(+-0, y) = +- 0   for y an odd integer
            if (isOddInteger(y)) {
                return math.copysign(f32, math.inf(f32), x);
            }
            // pow(+-0, y) = +inf   for y an even integer
            else {
                return math.inf(f32);
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
        // pow(-1, inf) = -1    for all x
        if (x == -1) {
            return -1;
        }
        // pow(x, +inf) = +0    for |x| < 1
        // pow(x, -inf) = +0    for |x| > 1
        else if ((math.fabs(x) < 1) == math.isPositiveInf(y)) {
            return 0;
        }
        // pow(x, -inf) = +inf  for |x| < 1
        // pow(x, +inf) = +inf  for |x| > 1
        else {
            return math.inf(f32);
        }
    }

    if (math.isInf(x)) {
        if (math.isNegativeInf(x)) {
            return pow32(1 / x, -y);
        }
        // pow(+inf, y) = +0    for y < 0
        else if (y < 0) {
            return 0;
        }
        // pow(+inf, y) = +0    for y > 0
        else if (y > 0) {
            return math.inf(f32);
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
        return math.nan(f32);
    }
    if (yi >= 1 << 31) {
        return math.exp(y * math.ln(x));
    }

    // a = a1 * 2^ae
    var a1: f32 = 1.0;
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

    var i = i32(yi);
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

    math.scalbn(a1, ae)
}

// This implementation is taken from the go stlib, musl is a bit more complex.
fn pow64(x: f64, y: f64) -> f64 {
    // pow(x, +-0) = 1      for all x
    // pow(1, y) = 1        for all y
    if (y == 0 or x == 1) {
        return 1;
    }

    // pow(nan, y) = nan    for all y
    // pow(x, nan) = nan    for all x
    if (math.isNan(x) or math.isNan(y)) {
        return math.nan(f64);
    }

    // pow(x, 1) = x        for all x
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
            // pow(+-0, y) = +- 0   for y an odd integer
            if (isOddInteger(y)) {
                return math.copysign(f64, math.inf(f64), x);
            }
            // pow(+-0, y) = +inf   for y an even integer
            else {
                return math.inf(f64);
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
        // pow(-1, inf) = -1    for all x
        if (x == -1) {
            return -1;
        }
        // pow(x, +inf) = +0    for |x| < 1
        // pow(x, -inf) = +0    for |x| > 1
        else if ((math.fabs(x) < 1) == math.isInf(y)) {
            return 0;
        }
        // pow(x, -inf) = +inf  for |x| < 1
        // pow(x, +inf) = +inf  for |x| > 1
        else {
            return math.inf(f64);
        }
    }

    if (math.isInf(x)) {
        if (math.isInf(x)) {
            return pow64(1 / x, -y);
        }
        // pow(+inf, y) = +0    for y < 0
        else if (y < 0) {
            return 0;
        }
        // pow(+inf, y) = +0    for y > 0
        else if (y > 0) {
            return math.inf(f64);
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
        return math.nan(f64);
    }
    if (yi >= 1 << 63) {
        return math.exp(y * math.ln(x));
    }

    // a = a1 * 2^ae
    var a1: f64 = 1.0;
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

    var i = i64(yi);
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

    math.scalbn(a1, ae)
}

test "pow" {
    assert(pow(f32, 0.2, 3.3) == pow32(0.2, 3.3));
    assert(pow(f64, 0.2, 3.3) == pow64(0.2, 3.3));
}

test "pow32" {
    const epsilon = 0.000001;

    // assert(math.approxEq(f32, pow32(0.0, 3.3), 0.0, epsilon)); // TODO: Handle div zero
    assert(math.approxEq(f32, pow32(0.8923, 3.3), 0.686572, epsilon));
    assert(math.approxEq(f32, pow32(0.2, 3.3), 0.004936, epsilon));
    assert(math.approxEq(f32, pow32(1.5, 3.3), 3.811546, epsilon));
    assert(math.approxEq(f32, pow32(37.45, 3.3), 155736.703125, epsilon));
    assert(math.approxEq(f32, pow32(89.123, 3.3), 2722489.5, epsilon));
}

test "pow64" {
    const epsilon = 0.000001;

    // assert(math.approxEq(f32, pow32(0.0, 3.3), 0.0, epsilon)); // TODO: Handle div zero
    assert(math.approxEq(f64, pow64(0.8923, 3.3), 0.686572, epsilon));
    assert(math.approxEq(f64, pow64(0.2, 3.3), 0.004936, epsilon));
    assert(math.approxEq(f64, pow64(1.5, 3.3), 3.811546, epsilon));
    assert(math.approxEq(f64, pow64(37.45, 3.3), 155736.7160616, epsilon));
    assert(math.approxEq(f64, pow64(89.123, 3.3), 2722490.231436, epsilon));
}

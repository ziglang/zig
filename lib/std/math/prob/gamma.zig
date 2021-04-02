// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.8:  June, 2000
// Copyright 1984, 1987, 1989, 1992, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;

usingnamespace @import("constants.zig");

const polevl = math.prob.polevl;
const p1evl = math.prob.p1evl;

const P = [_]f64{
    1.60119522476751861407E-4,
    1.19135147006586384913E-3,
    1.04213797561761569935E-2,
    4.76367800457137231464E-2,
    2.07448227648435975150E-1,
    4.94214826801497100753E-1,
    9.99999999999999996796E-1,
};

const Q = [_]f64{
    -2.31581873324120129819E-5,
    5.39605580493303397842E-4,
    -4.45641913851797240494E-3,
    1.18139785222060435552E-2,
    3.58236398605498653373E-2,
    -2.34591795718243348568E-1,
    7.14304917030273074085E-2,
    1.00000000000000000320E0,
};

const MAXGAM = 171.624376956302725;
const LOGPI = 1.14472988584940017414;

// Stirling's formula for the gamma function
const STIR = [_]f64{
    7.87311395793093628397E-4,
    -2.29549961613378126380E-4,
    -2.68132617805781232825E-3,
    3.47222221605458667310E-3,
    8.33333333333482257126E-2,
};

const MAXSTIR = 143.01608;
const SQTPI = 2.50662827463100050242E0;

/// Gamma function computed by Stirling's formula.
/// The polynomial STIR is valid for 33 <= x <= 172.
fn stirf(x: f64) f64 {
    var w = 1.0 / x;
    w = 1.0 + w * polevl(w, STIR[0..]);
    var y = math.exp(x);

    if (x > MAXSTIR) {
        // Avoid overflow in pow()
        var v = math.pow(f64, x, 0.5 * x - 0.25);
        y = v * (v / y);
    } else {
        y = math.pow(f64, x, x - 0.5) / y;
    }

    y = SQTPI * y * w;
    return y;
}

fn small(x: f64, z: f64) f64 {
    if (x == 0.0) {
        return math.nan(f64); // Domain
    }
    return z / ((1.0 + 0.5772156649015329 * x) * x);
}

/// Gamma function
///
/// Returns gamma function of the argument.  The result is
/// correctly signed, and the sign (+1 or -1) is also
/// returned in a global (extern) variable named sgngam.
/// This variable is also filled in by the logarithmic gamma
/// function lgam().
///
/// Arguments |x| <= 34 are reduced by recurrence and the function
/// approximated by a rational function of degree 6/7 in the
/// interval (2,3).  Large arguments are handled by Stirling's
/// formula. Large negative arguments are made positive using
/// a reflection formula.
///
///
/// ACCURACY:
///
///                      Relative error:
/// arithmetic   domain     # trials      peak         rms
///    DEC      -34, 34      10000       1.3e-16     2.5e-17
///    IEEE    -170,-33      20000       2.3e-15     3.3e-16
///    IEEE     -33,  33     20000       9.4e-16     2.2e-16
///    IEEE      33, 171.6   20000       2.3e-15     3.2e-16
///
/// Error for arguments outside the test range will be larger
/// owing to error amplification by the exponential function.
pub fn gamma(x_: f64) f64 {
    var x = x_;
    var sgngam: f64 = 1;

    if (math.isNan(x)) {
        return x;
    }
    if (math.isPositiveInf(x)) {
        return x;
    }
    if (math.isNegativeInf(x)) {
        return math.nan(f64);
    }

    var z: f64 = undefined;
    var q = math.fabs(x);
    if (q > 33.0) {
        if (x < 0.0) {
            var p = math.floor(q);
            if (p == q) {
                return math.nan(f64); // Domain
            }

            var i = @floatToInt(isize, p);
            if (i & 1 == 0) {
                sgngam = -1;
            }

            z = q - p;
            if (z > 0.5) {
                p += 1.0;
                z = q - p;
            }
            z = q * math.sin(PI * z);
            if (z == 0.0) {
                return sgngam * math.inf(f64);
            }
            z = math.fabs(z);
            z = PI / (z * stirf(q));
        } else {
            z = stirf(x);
        }

        return sgngam * z;
    }

    z = 1.0;
    while (x >= 3.0) {
        x -= 1.0;
        z *= x;
    }
    while (x < 0.0) {
        if (x > -1.e-9) {
            return small(x, z);
        }
        z /= x;
        x += 1.0;
    }

    while (x < 2.0) {
        if (x < 1.e-9) {
            return small(x, z);
        }
        z /= x;
        x += 1.0;
    }

    if (x == 2.0) {
        return z;
    }

    x -= 2.0;
    var p = polevl(x, P[0..]);
    q = polevl(x, Q[0..]);
    return z * p / q;
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 0.000001;

test "gamma" {
    expect(math.isNan(gamma(0)));
    expect(math.isNan(gamma(-1)));

    expectApproxEqRel(gamma(1), 1, epsilon);
    expectApproxEqRel(gamma(1.5), 0.886226925453, epsilon);
    expectApproxEqRel(gamma(1.9), 0.961765831907, epsilon);

    expectApproxEqRel(gamma(-0.5), -3.5449077018, epsilon);
}

// A[]: Stirling's formula expansion of log gamma
// B[], C[]: log gamma function between 2 and 3
const A = [_]f64{
    8.11614167470508450300E-4,
    -5.95061904284301438324E-4,
    7.93650340457716943945E-4,
    -2.77777777730099687205E-3,
    8.33333333333331927722E-2,
};
const B = [_]f64{
    -1.37825152569120859100E3,
    -3.88016315134637840924E4,
    -3.31612992738871184744E5,
    -1.16237097492762307383E6,
    -1.72173700820839662146E6,
    -8.53555664245765465627E5,
};
const C = [_]f64{
    // 1.00000000000000000000E0,
    -3.51815701436523470549E2,
    -1.70642106651881159223E4,
    -2.20528590553854454839E5,
    -1.13933444367982507207E6,
    -2.53252307177582951285E6,
    -2.01889141433532773231E6,
};

// log(sqrt( 2*pi ))
const LS2PI = 0.91893853320467274178;
const MAXLGM = 2.556348e305;

/// Natural logarithm of gamma function
///
/// Returns the base e (2.718...) logarithm of the absolute
/// value of the gamma function of the argument.
/// The sign (+1 or -1) of the gamma function is returned in a
/// global (extern) variable named sgngam.
///
/// For arguments greater than 13, the logarithm of the gamma
/// function is approximated by the logarithmic version of
/// Stirling's formula using a polynomial approximation of
/// degree 4. Arguments between -33 and +33 are reduced by
/// recurrence to the interval [2,3] of a rational approximation.
/// The cosecant reflection formula is employed for arguments
/// less than -33.
///
/// Arguments greater than MAXLGM return MAXNUM and an error
/// message.  MAXLGM = 2.035093e36 for DEC
/// arithmetic or 2.556348e305 for IEEE arithmetic.
///
///
/// ACCURACY:
///
///
/// arithmetic      domain        # trials     peak         rms
///    DEC     0, 3                  7000     5.2e-17     1.3e-17
///    DEC     2.718, 2.035e36       5000     3.9e-17     9.9e-18
///    IEEE    0, 3                 28000     5.4e-16     1.1e-16
///    IEEE    2.718, 2.556e305     40000     3.5e-16     8.3e-17
/// The error criterion was relative when the function magnitude
/// was greater than one but absolute when it was less than one.
///
/// The following test used the relative error criterion, though
/// at certain points the relative error could be much higher than
/// indicated.
///    IEEE    -200, -4             10000     4.8e-16     1.3e-16
pub fn lnGamma(x_: f64) f64 {
    var x = x_;
    var sgngam: f64 = 1;

    if (math.isNan(x)) {
        return x;
    }
    if (!math.isFinite(x)) {
        return math.inf(f64);
    }

    var z: f64 = undefined;
    if (x < -34.0) {
        var q = -x;
        var w = lnGamma(q);

        var p = math.floor(q);
        if (p == q) {
            return math.inf(f64); // Singularity
        }

        var i = @floatToInt(isize, p);
        sgngam = if (i & 1 == 0) -1 else 1;

        z = q - p;
        if (z > 0.5) {
            p += 1.0;
            z = p - q;
        }
        z = q * math.sin(PI * z);
        if (z == 0.0) {
            return math.inf(f64); // Singularity
        }

        //	z = log(PI) - log( z ) - w;
        z = LOGPI - math.ln(z) - w;
        return z;
    }

    if (x < 13.0) {
        z = 1.0;
        var p: f64 = 0.0;
        var u = x;

        while (u >= 3.0) {
            p -= 1.0;
            u = x + p;
            z *= u;
        }
        while (u < 2.0) {
            if (u == 0.0) {
                return math.inf(f64); // Singularity
            }
            z /= u;
            p += 1.0;
            u = x + p;
        }
        if (z < 0.0) {
            sgngam = -1;
            z = -z;
        } else {
            sgngam = 1;
        }

        if (u == 2.0) {
            return math.ln(z);
        }

        p -= 2.0;
        x = x + p;
        p = x * polevl(x, B[0..]) / p1evl(x, C[0..]);
        return math.ln(z) + p;
    }

    if (x > MAXLGM) {
        return sgngam * math.inf(f64);
    }

    var q = (x - 0.5) * math.ln(x) - x + LS2PI;
    if (x > 1.0e8) {
        return q;
    }

    var p = 1.0 / (x * x);
    if (x >= 1000.0) {
        q += ((7.9365079365079365079365e-4 * p - 2.7777777777777777777778e-3) * p + 0.0833333333333333333333) / x;
    } else {
        q += polevl(p, A[0..]) / x;
    }

    return q;
}

test "lnGamma" {
    expect(math.isInf(lnGamma(0)));
    expect(math.isInf(lnGamma(-1)));

    expectApproxEqRel(lnGamma(1), 0, epsilon);
    expectApproxEqRel(lnGamma(1.5), -0.12078223764, epsilon);
    expectApproxEqRel(lnGamma(1.9), -0.03898427592, epsilon);

    expectApproxEqRel(lnGamma(-0.5), 1.26551212348, epsilon);
}

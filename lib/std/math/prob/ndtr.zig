// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
// Cephes Math Library Release 2.9:  November, 2000
// Copyright 1984, 1987, 1988, 1992, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;

usingnamespace @import("constants.zig");

const polevl = math.prob.polevl;
const p1evl = math.prob.p1evl;
const expx2 = @import("expx2.zig").expx2;

// Define this macro to suppress error propagation in exp(x^2)
// by using the expx2 function.  The tradeoff is that doing so
// generates two calls to the exponential function instead of one.  */
const USE_EXPXSQ = true;

const P = [_]f64{
    2.46196981473530512524E-10, 5.64189564831068821977E-1,
    7.46321056442269912687E0,   4.86371970985681366614E1,
    1.96520832956077098242E2,   5.26445194995477358631E2,
    9.34528527171957607540E2,   1.02755188689515710272E3,
    5.57535335369399327526E2,
};

const Q = [_]f64{
    1.32281951154744992508E1, 8.67072140885989742329E1,
    3.54937778887819891062E2, 9.75708501743205489753E2,
    1.82390916687909736289E3, 2.24633760818710981792E3,
    1.65666309194161350182E3, 5.57535340817727675546E2,
};

const R = [_]f64{
    5.64189583547755073984E-1, 1.27536670759978104416E0,
    5.01905042251180477414E0,  6.16021097993053585195E0,
    7.40974269950448939160E0,  2.97886665372100240670E0,
};

const S = [_]f64{
    2.26052863220117276590E0, 9.39603524938001434673E0,
    1.20489539808096656605E1, 1.70814450747565897222E1,
    9.60896809063285878198E0, 3.36907645100081516050E0,
};

const T = [_]f64{
    9.60497373987051638749E0, 9.00260197203842689217E1,
    2.23200534594684319226E3, 7.00332514112805075473E3,
    5.55923013010394962768E4,
};

const U = [_]f64{
    3.35617141647503099647E1, 5.21357949780152679795E2,
    4.59432382970980127987E3, 2.26290000613890934246E4,
    4.92673942608635921086E4,
};

const UTHRESH = 37.519379347;

/// Normal distribution function
///
/// Returns the area under the Gaussian probability density
/// function, integrated from minus infinity to x:
///
///                            x
///                             -
///                   1        | |          2
///    ndtr(x)  = ---------    |    exp( - t /2 ) dt
///               sqrt(2pi)  | |
///                           -
///                          -inf.
///
///             =  ( 1 + erf(z) ) / 2
///             =  erfc(z) / 2
///
/// where z = x/sqrt(2). Computation is via the functions
/// erf and erfc with care to avoid error amplification in computing exp(-x^2).
///
///
/// ACCURACY:
///
///                      Relative error:
/// arithmetic   domain     # trials      peak         rms
///    IEEE     -13,0        30000       1.3e-15     2.2e-16
///
///
/// ERROR MESSAGES:
///
///   message         condition         value returned
/// erfc underflow    x > 37.519379347       0.0
pub fn ndtr(a: f64) f64 {
    var x = a * SQRTH;
    var z = math.fabs(x);

    if (z < 1.0) {
        return 0.5 + 0.5 * erf(x);
    }

    var y = blk: {
        if (USE_EXPXSQ) {
            // See below for erfce.
            const w = 0.5 * erfce(z);
            // Multiply by exp(-x^2 / 2)
            z = expx2(a, -1);
            break :blk w * math.sqrt(z);
        } else {
            break :blk 0.5 * erfc(z);
        }
    };

    if (x > 0) {
        y = 1.0 - y;
    }

    return y;
}

fn under(a: f64) f64 {
    return if (a < 0) 2.0 else 0.0; // Underflow
}

/// Complementary error function
///
///  1 - erf(x) =
///
///                           inf.
///                             -
///                  2         | |          2
///   erfc(x)  =  --------     |    exp( - t  ) dt
///               sqrt(pi)   | |
///                           -
///                            x
///
///
/// For small x, erfc(x) = 1 - erf(x); otherwise rational
/// approximations are computed.
///
/// A special function expx2.c is used to suppress error amplification
/// in computing exp(-x^2).
///
///
/// ACCURACY:
///
///                      Relative error:
/// arithmetic   domain     # trials      peak         rms
///    IEEE      0,26.6417   30000       1.3e-15     2.2e-16
///
///
/// ERROR MESSAGES:
///
///   message         condition              value returned
/// erfc underflow    x > 9.231948545 (DEC)       0.0
pub fn erfc(a: f64) f64 {
    var x = if (a < 0.0) -a else a;
    if (x < 1.0) {
        return 1.0 - erf(a);
    }

    var z = -a * a;

    if (z < -MAXLOG) {
        return under(a);
    }

    if (USE_EXPXSQ) {
        // Compute z = exp(z).
        z = expx2(a, -1);
    } else {
        z = math.exp(z);
    }

    var p: f64 = undefined;
    var q: f64 = undefined;
    if (x < 8.0) {
        p = polevl(x, P[0..]);
        q = p1evl(x, Q[0..]);
    } else {
        p = polevl(x, R[0..]);
        q = p1evl(x, S[0..]);
    }

    var y = (z * p) / q;

    if (a < 0) {
        y = 2.0 - y;
    }

    if (y == 0.0) {
        return under(a);
    }

    return y;
}

/// Exponentially scaled erfc function
/// exp(x^2) erfc(x)
/// valid for x > 1.
/// Use with ndtr and expx2.
fn erfce(x: f64) f64 {
    var p: f64 = undefined;
    var q: f64 = undefined;
    if (x < 8.0) {
        p = polevl(x, P[0..]);
        q = p1evl(x, Q[0..]);
    } else {
        p = polevl(x, R[0..]);
        q = p1evl(x, S[0..]);
    }

    return p / q;
}

/// Error function
///
/// The integral is
///
///                           x
///                            -
///                 2         | |          2
///   erf(x)  =  --------     |    exp( - t  ) dt.
///              sqrt(pi)   | |
///                          -
///                           0
///
/// The magnitude of x is limited to 9.231948545 for DEC
/// arithmetic; 1 or -1 is returned outside this range.
///
/// For 0 <= |x| < 1, erf(x) = x * P4(x**2)/Q5(x**2); otherwise
/// erf(x) = 1 - erfc(x).
///
///
/// ACCURACY:
///
///                      Relative error:
/// arithmetic   domain     # trials      peak         rms
///    DEC       0,1         14000       4.7e-17     1.5e-17
///    IEEE      0,1         30000       3.7e-16     1.0e-16
pub fn erf(x: f64) f64 {
    if (math.fabs(x) > 1.0) {
        return 1.0 - erfc(x);
    }

    var z = x * x;
    var y = x * polevl(z, T[0..]) / p1evl(z, U[0..]);
    return y;
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e-7;

test "erf" {
    expectApproxEqRel(erf(0), 0, epsilon);
    expectApproxEqRel(erf(1), 0.8427007929497, epsilon);
    expectApproxEqRel(erf(-1), -0.8427007929497, epsilon);
    expectApproxEqRel(erf(5), 0.9999999999984625, epsilon);
}

test "erfc" {
    expectApproxEqRel(erfc(0), 1, epsilon);
    expectApproxEqRel(erfc(1), 0.157299207050285, epsilon);
    expectApproxEqRel(erfc(-1), 1.84270079294971, epsilon);
    expectApproxEqRel(erfc(5), 1.5374597944280e-12, epsilon);
}

test "erfce" {
    expectApproxEqRel(erfce(0), 1, epsilon);
    expectApproxEqRel(erfce(1), 0.4275835761558, epsilon);
    expectApproxEqRel(erfce(-1), 5.008980080762283, 1e-3); // TODO: Confirm against c implementation
    expectApproxEqRel(erfce(5), 0.1107046377339686, epsilon);
}

test "ndtr" {
    const e2 = 1e-3; // TODO: Get more accurate reference

    expectApproxEqRel(ndtr(-10), 7.62e-24, e2);
    expectApproxEqRel(ndtr(-1), 0.1587, e2);
    expectApproxEqRel(ndtr(0), 0.5, e2);
    expectApproxEqRel(ndtr(1), 0.8413, e2);
    expectApproxEqRel(ndtr(5), 1 - 2.867e-7, e2);
}

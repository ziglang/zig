// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.8:  June, 2000
// Copyright 1985, 1987, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;

usingnamespace @import("constants.zig");

const lnGamma = math.prob.lnGamma;

/// Incomplete gamma integral
///
/// The function is defined by
///
///                           x
///                            -
///                   1       | |  -t  a-1
///  igam(a,x)  =   -----     |   e   t   dt.
///                  -      | |
///                 | (a)    -
///                           0
///
///
/// In this implementation both arguments must be positive.
/// The integral is evaluated by either a power series or
/// continued fraction expansion, depending on the relative
/// values of a and x.
///
/// ACCURACY:
///
///                      Relative error:
/// arithmetic   domain     # trials      peak         rms
///    IEEE      0,30       200000       3.6e-14     2.9e-15
///    IEEE      0,100      300000       9.9e-14     1.5e-14
////
///
/// left tail of incomplete gamma function:
///
///          inf.      k
///   a  -x   -       x
///  x  e     >   ----------
///           -     -
///          k=0   | (a+k+1)
pub fn incompleteGamma(a: f64, x: f64) f64 {
    if (x <= 0 or a <= 0) {
        return 0.0;
    }

    if (x > 1.0 and x > a) {
        return 1.0 - complementedIncompleteGamma(a, x);
    }

    // TODO: Verify this condition, are we flipped with igamc?
    if (math.isInf(x)) {
        return 1.0;
    }

    // Compute  x**a * exp(-x) / gamma(a)
    var ax = a * math.ln(x) - x - lnGamma(a);
    if (ax < -MAXLOG) {
        return 0.0; // Underflow
    }
    ax = math.exp(ax);

    // power series
    var r: f64 = a;
    var c: f64 = 1.0;
    var ans: f64 = 1.0;

    // mimic do-while
    while (true) {
        r += 1.0;
        c *= x / r;
        ans += c;

        if (c / ans <= MACHEP) break;
    }

    return ans * ax / a;
}

test "incompleteGamma" {
    const cases = [_][3]f64{
        [_]f64{ 0, 0, 0 },
        [_]f64{ 0.0001, 1, 0.99997805936186279 },
        [_]f64{ 0.001, 0.005, 0.99528424172333985 },
        [_]f64{ 0.01, 10, 0.99999995718295021 },
        [_]f64{ 0.1, 10, 0.99999944520142825 },
        [_]f64{ 0.25, 0.75, 0.89993651328449831 },
        [_]f64{ 0.5, 0.5, 0.68268949213708596 },
        [_]f64{ 0.5, 2, 0.95449973610364147 },
        [_]f64{ 0.75, 2.5, 0.95053039734695643 },
        [_]f64{ 1, 0.5, 0.39346934028736652 },
        [_]f64{ 1, 1, 0.63212055882855778 },
        [_]f64{ 1.5, 0.75, 0.31772966966378746 },
        [_]f64{ 2.5, 1, 0.15085496391539038 },
        [_]f64{ 3, 0.05, 2.0067493624397931e-05 },
        [_]f64{ 3, 20, 0.99999954448504946 },
        [_]f64{ 5, 50, 1 },
        [_]f64{ 7, 10, 0.86985857911751696 },
        [_]f64{ 10, 0.9, 4.2519575433351128e-08 },
        [_]f64{ 10, 5, 0.031828057306204811 },
        [_]f64{ 25, 10, 4.6949381426799868e-05 },
    };

    for (cases) |c| {
        expectApproxEqRel(incompleteGamma(c[0], c[1]), c[2], epsilon);
    }
}

const big = 4.503599627370496e15;
const biginv = 2.22044604925031308085e-16;

/// Complemented incomplete gamma integral
///
/// The function is defined by
///
///
///  igamc(a,x)   =   1 - igam(a,x)
///
///                            inf.
///                              -
///                     1       | |  -t  a-1
///               =   -----     |   e   t   dt.
///                    -      | |
///                   | (a)    -
///                             x
///
///
/// In this implementation both arguments must be positive.
/// The integral is evaluated by either a power series or
/// continued fraction expansion, depending on the relative
/// values of a and x.
///
/// ACCURACY:
///
/// Tested at random a, x.
///                a         x                      Relative error:
/// arithmetic   domain   domain     # trials      peak         rms
///    IEEE     0.5,100   0,100      200000       1.9e-14     1.7e-15
///    IEEE     0.01,0.5  0,100      200000       1.4e-13     1.6e-15
pub fn complementedIncompleteGamma(a: f64, x: f64) f64 {
    if (x <= 0 or a <= 0) {
        return 1.0;
    }

    if (x < 1.0 or x < a) {
        return 1.0 - incompleteGamma(a, x);
    }

    // TODO: Verify this condition, are we flipped with igam?
    if (math.isInf(x)) {
        return 0.0;
    }

    var ax = a * math.ln(x) - x - lnGamma(a);
    if (ax < -MAXLOG) {
        return 0.0; // Underflow
    }
    ax = math.exp(ax);

    // continued fraction
    var y: f64 = 1.0 - a;
    var z: f64 = x + y + 1.0;
    var c: f64 = 0.0;
    var pkm2: f64 = 1.0;
    var qkm2: f64 = x;
    var pkm1: f64 = x + 1.0;
    var qkm1: f64 = z * x;
    var ans: f64 = pkm1 / qkm1;

    while (true) {
        c += 1.0;
        y += 1.0;
        z += 2.0;
        const yc = y * c;
        const pk = pkm1 * z - pkm2 * yc;
        const qk = qkm1 * z - qkm2 * yc;

        const t = blk: {
            if (qk != 0) {
                const r = pk / qk;
                const tv = math.fabs((ans - r) / r);
                ans = r;
                break :blk tv;
            } else {
                break :blk 1.0;
            }
        };

        pkm2 = pkm1;
        pkm1 = pk;
        qkm2 = qkm1;
        qkm1 = qk;
        if (math.fabs(pk) > big) {
            pkm2 *= biginv;
            pkm1 *= biginv;
            qkm2 *= biginv;
            qkm1 *= biginv;
        }

        if (t <= MACHEP) break;
    }

    return ans * ax;
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e-2; // TODO: Improve precision

// Test cases from gonum/gonum
test "complementedIncompleteGamma" {
    const cases = [_][3]f64{
        [_]f64{ 0.00001, 0.075, 2.0866541002417804e-05 },
        [_]f64{ 0.0001, 1, 2.1940638138146658e-05 },
        [_]f64{ 0.001, 0.005, 0.0047157582766601536 },
        [_]f64{ 0.01, 0.9, 0.0026263432520514662 },
        [_]f64{ 0.25, 0.75, 0.10006348671550169 },
        [_]f64{ 0.5, 0.5, 0.31731050786291404 },
        [_]f64{ 0.75, 0.25, 0.65343980284081038 },
        [_]f64{ 0.9, 0.01, 0.98359881081593148 },
        [_]f64{ 1, 0, 1 },
        [_]f64{ 1, 0.075, 0.92774348632855297 },
        [_]f64{ 1, 1, 0.36787944117144233 },
        [_]f64{ 1, 10, 4.5399929762484861e-05 },
        [_]f64{ 1, math.inf(f64), 0 },
        [_]f64{ 3, 20, 4.5551495055892125e-07 },
        [_]f64{ 5, 10, 0.029252688076961127 },
        [_]f64{ 10, 3, 0.99889751186988451 },
        [_]f64{ 50, 25, 0.99999304669475242 },
        [_]f64{ 100, 10, 1 },
        [_]f64{ 500, 500, 0.49405285382921321 },
        [_]f64{ 500, 550, 0.014614408126291296 },
    };

    for (cases) |c| {
        expectApproxEqRel(complementedIncompleteGamma(c[0], c[1]), c[2], epsilon);
    }
}

const inverseNormalDist = math.prob.inverseNormalDist;

/// Inverse of complemented imcomplete gamma integral
///
/// Given p, the function finds x such that
///
///  igamc( a, x ) = p.
///
/// Starting with the approximate value
///
///         3
///  x = a t
///
///  where
///
///  t = 1 - d - ndtri(p) sqrt(d)
///
/// and
///
///  d = 1/9a,
///
/// the routine performs up to 10 Newton iterations to find the
/// root of igamc(a,x) - p = 0.
///
/// ACCURACY:
///
/// Tested at random a, p in the intervals indicated.
///
///                a        p                      Relative error:
/// arithmetic   domain   domain     # trials      peak         rms
///    IEEE     0.5,100   0,0.5       100000       1.0e-14     1.7e-15
///    IEEE     0.01,0.5  0,0.5       100000       9.0e-14     3.4e-15
///    IEEE    0.5,10000  0,0.5        20000       2.3e-13     3.8e-14
pub fn inverseComplementedIncompleteGamma(a: f64, y0: f64) f64 {
    var i: usize = 0;

    // bound the solution
    var x0: f64 = MAXNUM;
    var yl: f64 = 0;
    var x1: f64 = 0;
    var yh: f64 = 1.0;
    var dithresh: f64 = 5.0 * MACHEP;

    // approximation to inverse function
    var d: f64 = 1.0 / (9.0 * a);
    var y: f64 = (1.0 - d - inverseNormalDist(y0) * math.sqrt(d));
    var x: f64 = a * y * y * y;

    var lgm = lnGamma(a);

    i = 0;
    while (i < 10) : (i += 1) {
        if (x > x0 or x < x1) {
            break;
        }

        y = complementedIncompleteGamma(a, x);
        if (y < yl or y > yh) {
            break;
        }
        if (y < y0) {
            x0 = x;
            yl = y;
        } else {
            x1 = x;
            yh = y;
        }
        // compute the derivative of the function at this point
        d = (a - 1.0) * math.ln(x) - x - lgm;
        if (d < -MAXLOG) {
            break;
        }
        d = -math.exp(d);
        // compute the step to the next approximation of x
        d = (y - y0) / d;
        if (math.fabs(d / x) < MACHEP) {
            return x; // done
        }
        x = x - d;
    }

    // Resort to interval halving if Newton iteration did not converge.
    // ihalve:

    d = 0.0625;
    if (x0 == MAXNUM) {
        if (x <= 0.0) {
            x = 1.0;
        }
        while (x0 == MAXNUM) {
            x = (1.0 + d) * x;
            y = complementedIncompleteGamma(a, x);
            if (y < y0) {
                x0 = x;
                yl = y;
                break;
            }
            d = d + d;
        }
    }

    d = 0.5;
    var dir: f64 = 0;

    i = 0;
    while (i < 400) : (i += 1) {
        x = x1 + d * (x0 - x1);
        y = complementedIncompleteGamma(a, x);
        lgm = (x0 - x1) / (x1 + x0);
        if (math.fabs(lgm) < dithresh) {
            break;
        }
        lgm = (y - y0) / y0;
        if (math.fabs(lgm) < dithresh) {
            break;
        }
        if (x <= 0.0) {
            break;
        }
        if (y >= y0) {
            x1 = x;
            yh = y;
            if (dir < 0) {
                dir = 0;
                d = 0.5;
            } else if (dir > 1) {
                d = 0.5 * d + 0.5;
            } else {
                d = (y0 - yl) / (yh - yl);
            }
            dir += 1;
        } else {
            x0 = x;
            yl = y;
            if (dir > 0) {
                dir = 0;
                d = 0.5;
            } else if (dir < -1) {
                d = 0.5 * d;
            } else {
                d = (y0 - yl) / (yh - yl);
            }
            dir -= 1;
        }
    }

    if (x == 0.0) {
        // Underflow
    }

    return x;
}

test "inverseComplementedIncompleteGamma" {
    const cases = [_][3]f64{
        [_]f64{ 0.001, 0.01, 2.4259428385570885e-05 },
        [_]f64{ 0.01, 0.01, 0.26505255025158292 },
        [_]f64{ 0.03, 0.4, 2.316980536227699e-08 },
        [_]f64{ 0.1, 0.5, 0.00059339110446022798 },
        [_]f64{ 0.1, 0.75, 5.7917132949696076e-07 },
        [_]f64{ 0.25, 0.25, 0.26062600197823282 },
        [_]f64{ 0.5, 0.1, 1.3527717270477047 },
        [_]f64{ 0.5, 0.5, 0.22746821155978625 },
        [_]f64{ 0.75, 0.25, 1.0340914067758025 },
        //[_]f64{ 1, 0, math.inf(f64) },
        [_]f64{ 1, 0.5, 0.69314718055994529 },
        //[_]f64{ 1, 1, 0 },    // Should be valid?
        [_]f64{ 3, 0.75, 1.727299417860519 },
        [_]f64{ 25, 0.4, 25.945791937289371 },
        [_]f64{ 25, 0.7, 22.156653488661991 },
        [_]f64{ 10, 0.5, 9.6687146147141299 },
        [_]f64{ 100, 0.25, 106.5510925269767 },
        [_]f64{ 1000, 0.01, 1075.0328320864389 },
        [_]f64{ 1000, 0.99, 927.90815979664251 },
        [_]f64{ 10000, 0.5, 9999.6666686420485 },
    };

    for (cases) |c| {
        expectApproxEqRel(inverseComplementedIncompleteGamma(c[0], c[1]), c[2], epsilon);
    }
}

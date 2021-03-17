// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.8:  June, 2000
// Copyright 1984, 1987, 1995, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;

usingnamespace @import("constants.zig");

const ndtri = math.prob.ndtri;
const lgam = math.prob.lgam;
const igamc = math.prob.igamc;

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
pub fn igami(a: f64, y0: f64) f64 {
    var i: usize = 0;

    // bound the solution
    var x0: f64 = MAXNUM;
    var yl: f64 = 0;
    var x1: f64 = 0;
    var yh: f64 = 1.0;
    var dithresh: f64 = 5.0 * MACHEP;

    // approximation to inverse function
    var d: f64 = 1.0 / (9.0 * a);
    var y: f64 = (1.0 - d - ndtri(y0) * math.sqrt(d));
    var x: f64 = a * y * y * y;

    var lgm = lgam(a);

    i = 0;
    while (i < 10) : (i += 1) {
        if (x > x0 or x < x1) {
            break;
        }

        y = igamc(a, x);
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
            y = igamc(a, x);
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
        y = igamc(a, x);
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

const expectApproxEqRel = std.testing.expectApproxEqRel;
const epsilon = 0.000001;

test "igami" {
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
        expectApproxEqRel(igami(c[0], c[1]), c[2], epsilon);
    }
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library, Release 2.8:  June, 2000
// Copyright 1984, 1995, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;

usingnamespace @import("constants.zig");

const gamma = math.prob.gamma;
const lgam = math.prob.lgam;

const MAXGAM = 34.84425627277176174;
const big = 4.503599627370496e15;
const biginv = 2.22044604925031308085e-16;

fn done(flag: bool, t: f64) f64 {
    if (flag) {
        if (t <= MACHEP) {
            return 1.0 - MACHEP;
        } else {
            return 1.0 - t;
        }
    }
    return t;
}

/// Incomplete beta integral
///
/// Returns incomplete beta integral of the arguments, evaluated
/// from zero to x.  The function is defined as
///
///                  x
///     -            -
///    | (a+b)      | |  a-1     b-1
///  -----------    |   t   (1-t)   dt.
///   -     -     | |
///  | (a) | (b)   -
///                 0
///
/// The domain of definition is 0 <= x <= 1.  In this
/// implementation a and b are restricted to positive values.
/// The integral from x to 1 may be obtained by the symmetry
/// relation
///
///    1 - incbet( a, b, x )  =  incbet( b, a, 1-x ).
///
/// The integral is evaluated by a continued fraction expansion
/// or, when b*x is small, by a power series.
///
/// ACCURACY:
///
/// Tested at uniformly distributed random points (a,b,x) with a and b
/// in "domain" and x between 0 and 1.
///                                        Relative error
/// arithmetic   domain     # trials      peak         rms
///    IEEE      0,5         10000       6.9e-15     4.5e-16
///    IEEE      0,85       250000       2.2e-13     1.7e-14
///    IEEE      0,1000      30000       5.3e-12     6.3e-13
///    IEEE      0,10000    250000       9.3e-11     7.1e-12
///    IEEE      0,100000    10000       8.7e-10     4.8e-11
/// Outputs smaller than the IEEE gradual underflow threshold
/// were excluded from these statistics.
///
/// ERROR MESSAGES:
///   message         condition      value returned
/// incbet domain      x<0, x>1          0.0
/// incbet underflow                     0.0
pub fn incbet(aa: f64, bb: f64, xx: f64) f64 {
    if (aa <= 0.0 or bb <= 0.0) {
        return 0.0; // Domain
    }

    if (xx <= 0.0 or xx >= 1.0) {
        if (xx == 0.0) {
            return (0.0);
        }
        if (xx == 1.0) {
            return 1.0;
        }

        return 0.0; // Domain
    }

    var flag = false;

    if (bb * xx <= 1.0 and xx <= 0.95) {
        const t = pseries(aa, bb, xx);
        return done(flag, t);
    }

    var w = 1.0 - xx;
    var a = aa;
    var b = bb;
    var xc = w;
    var x = xx;

    // Reverse a and b if x is greater than the mean.
    if (xx > aa / (aa + bb)) {
        flag = true;
        a = bb;
        b = aa;
        xc = xx;
        x = w;
    }

    if (flag and b * x <= 1.0 and x <= 0.95) {
        const t = pseries(a, b, x);
        return done(flag, t);
    }

    // Choose expansion for better convergence.
    var y = x * (a + b - 2.0) - (a - 1.0);
    if (y < 0.0) {
        w = incbcf(a, b, x);
    } else {
        w = incbd(a, b, x) / xc;
    }

    // Multiply w by the factor
    //   a      b   _             _     _
    //  x  (1-x)   | (a+b) / ( a | (a) | (b) )
    y = a * math.ln(x);
    var t = b * math.ln(xc);
    if (a + b < MAXGAM and math.fabs(y) < MAXLOG and math.fabs(t) < MAXLOG) {
        t = math.pow(f64, xc, b);
        t *= math.pow(f64, x, a);
        t /= a;
        t *= w;
        t *= gamma(a + b) / (gamma(a) * gamma(b));
        return done(flag, t);
    }

    // Resort to logarithms.
    y += t + lgam(a + b) - lgam(a) - lgam(b);
    y += math.ln(w / a);
    if (y < MINLOG) {
        t = 0.0;
    } else {
        t = math.exp(y);
    }

    return done(flag, t);
}

/// Continued fraction expansion #1
/// for incomplete beta integral
pub fn incbcf(a: f64, b: f64, x: f64) f64 {
    var k1 = a;
    var k2 = a + b;
    var k3 = a;
    var k4 = a + 1.0;
    var k5 = @as(f64, 1.0);
    var k6 = b - 1.0;
    var k7 = k4;
    var k8 = a + 2.0;

    var pkm2: f64 = 0;
    var qkm2: f64 = 1;
    var pkm1: f64 = 1;
    var qkm1: f64 = 1;
    var ans: f64 = 1;
    var r: f64 = 1;
    var n: f64 = 0;
    var thresh: f64 = 3.0 * MACHEP;

    // mimic do-while
    while (true) {
        var xk = -(x * k1 * k2) / (k3 * k4);
        var pk = pkm1 + pkm2 * xk;
        var qk = qkm1 + qkm2 * xk;
        pkm2 = pkm1;
        pkm1 = pk;
        qkm2 = qkm1;
        qkm1 = qk;

        xk = (x * k5 * k6) / (k7 * k8);
        pk = pkm1 + pkm2 * xk;
        qk = qkm1 + qkm2 * xk;
        pkm2 = pkm1;
        pkm1 = pk;
        qkm2 = qkm1;
        qkm1 = qk;

        if (qk != 0) {
            r = pk / qk;
        }

        var t: f64 = 1.0;
        if (r != 0) {
            t = math.fabs((ans - r) / r);
            ans = r;
        }

        if (t < thresh) {
            break;
        }

        k1 += 1.0;
        k2 += 1.0;
        k3 += 2.0;
        k4 += 2.0;
        k5 += 1.0;
        k6 -= 1.0;
        k7 += 2.0;
        k8 += 2.0;

        if (math.fabs(qk) + math.fabs(pk) > big) {
            pkm2 *= biginv;
            pkm1 *= biginv;
            qkm2 *= biginv;
            qkm1 *= biginv;
        }

        if (math.fabs(qk) < biginv or math.fabs(pk) < biginv) {
            pkm2 *= big;
            pkm1 *= big;
            qkm2 *= big;
            qkm1 *= big;
        }

        n += 1;
        if (n >= 300) break;
    }

    return ans;
}

/// Continued fraction expansion #2
/// for incomplete beta integral
pub fn incbd(a: f64, b: f64, x: f64) f64 {
    var k1 = a;
    var k2 = b - 1.0;
    var k3 = a;
    var k4 = a + 1.0;
    var k5 = @as(f64, 1.0);
    var k6 = a + b;
    var k7 = a + 1.0;
    var k8 = a + 2.0;

    var pkm2: f64 = 0;
    var qkm2: f64 = 1;
    var pkm1: f64 = 1;
    var qkm1: f64 = 1;
    var z: f64 = x / (1.0 - x);
    var ans: f64 = 1;
    var r: f64 = 1;
    var n: f64 = 0;
    var thresh: f64 = 3.0 * MACHEP;

    // mimic do-while
    while (true) {
        var xk = -(z * k1 * k2) / (k3 * k4);
        var pk = pkm1 + pkm2 * xk;
        var qk = qkm1 + qkm2 * xk;
        pkm2 = pkm1;
        pkm1 = pk;
        qkm2 = qkm1;
        qkm1 = qk;

        xk = (z * k5 * k6) / (k7 * k8);
        pk = pkm1 + pkm2 * xk;
        qk = qkm1 + qkm2 * xk;
        pkm2 = pkm1;
        pkm1 = pk;
        qkm2 = qkm1;
        qkm1 = qk;

        if (qk != 0) {
            r = pk / qk;
        }

        const t = blk: {
            if (r != 0) {
                const tv = math.fabs((ans - r) / r);
                ans = r;
                break :blk tv;
            } else {
                break :blk 1.0;
            }
        };

        if (t < thresh) {
            break;
        }

        k1 += 1.0;
        k2 -= 1.0;
        k3 += 2.0;
        k4 += 2.0;
        k5 += 1.0;
        k6 += 1.0;
        k7 += 2.0;
        k8 += 2.0;

        if (math.fabs(qk) + math.fabs(pk) > big) {
            pkm2 *= biginv;
            pkm1 *= biginv;
            qkm2 *= biginv;
            qkm1 *= biginv;
        }
        if (math.fabs(qk) < biginv or math.fabs(pk) < biginv) {
            pkm2 *= big;
            pkm1 *= big;
            qkm2 *= big;
            qkm1 *= big;
        }

        n += 1;
        while (n >= 300) break;
    }

    return ans;
}

/// Power series for incomplete beta integral.
/// Use when b*x is small and x not too close to 1.
pub fn pseries(a: f64, b: f64, x: f64) f64 {
    var ai = 1.0 / a;
    var u = (1.0 - b) * x;
    var v = u / (a + 1.0);
    var t1 = v;
    var t = u;
    var n: f64 = 2.0;
    var s: f64 = 0.0;
    var z: f64 = MACHEP * ai;

    while (math.fabs(v) > z) {
        u = (n - b) * x / n;
        t *= u;
        v = t / (a + n);
        s += v;
        n += 1.0;
    }

    s += t1;
    s += ai;

    u = a * math.ln(x);
    if ((a + b) < MAXGAM and math.fabs(u) < MAXLOG) {
        t = gamma(a + b) / (gamma(a) * gamma(b));
        s = s * t * math.pow(f64, x, a);
    } else {
        t = lgam(a + b) - lgam(a) - lgam(b) + u + math.ln(s);
        if (t < MINLOG) {
            s = 0.0;
        } else {
            s = math.exp(t);
        }
    }

    return s;
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e-10;

test "incbet" {
    const cases = [_][4]f64{
        [_]f64{ 1, 1, 0.8, 0.8 },
        [_]f64{ 1, 5, 0.8, 0.99968000000000001 },
        [_]f64{ 10, 10, 0.8, 0.99842087945083291 },
        [_]f64{ 10, 10, 0.1, 3.929882327128003e-06 },
        [_]f64{ 10, 2, 0.4, 0.00073400320000000028 },
        [_]f64{ 0.1, 0.2, 0.6, 0.69285678232066683 },
        [_]f64{ 1, 10, 0.7489, 0.99999900352334858 },
    };

    for (cases) |c| {
        expectApproxEqRel(incbet(c[0], c[1], c[2]), c[3], epsilon);
        expectApproxEqRel(1 - incbet(c[1], c[0], 1 - c[2]), c[3], epsilon);
    }
}

const ndtri = math.prob.ndtri;

/// Inverse of imcomplete beta integral
///
/// Given y, the function finds x such that
///
///  incbet( a, b, x ) = y .
///
/// The routine performs interval halving or Newton iterations to find the
/// root of incbet(a,b,x) - y = 0.
///
///
/// ACCURACY:
///
///                      Relative error:
///                x     a,b
/// arithmetic   domain  domain  # trials    peak       rms
///    IEEE      0,1    .5,10000   50000    5.8e-12   1.3e-13
///    IEEE      0,1   .25,100    100000    1.8e-13   3.9e-15
///    IEEE      0,1     0,5       50000    1.1e-12   5.5e-15
///    VAX       0,1    .5,100     25000    3.5e-14   1.1e-15
/// With a and b constrained to half-integer or integer values:
///    IEEE      0,1    .5,10000   50000    5.8e-12   1.1e-13
///    IEEE      0,1    .5,100    100000    1.7e-14   7.9e-16
/// With a = .5, b constrained to half-integer or integer values:
///    IEEE      0,1    .5,10000   10000    8.3e-11   1.0e-11
pub fn incbi(aa: f64, bb: f64, yy0: f64) f64 {
    if (yy0 <= 0) {
        return 0.0;
    }
    if (yy0 >= 1.0) {
        return 1.0;
    }

    const State = enum {
        ihalve,
        newton,
    };
    var state = State.ihalve;

    var rflg = false;
    var dithresh: f64 = undefined;
    var a: f64 = undefined;
    var b: f64 = undefined;
    var x: f64 = undefined;
    var y: f64 = undefined;
    var yp: f64 = undefined;
    var y0: f64 = undefined;

    while (true) {
        if (aa <= 1.0 or bb <= 1.0) {
            dithresh = 1.0e-6;
            rflg = false;
            a = aa;
            b = bb;
            y0 = yy0;
            x = a / (a + b);
            y = incbet(a, b, x);
            state = .ihalve;
            break;
        } else {
            dithresh = 1.0e-4;
        }

        // approximation to inverse function

        yp = -ndtri(yy0);

        if (yy0 > 0.5) {
            rflg = true;
            a = bb;
            b = aa;
            y0 = 1.0 - yy0;
            yp = -yp;
        } else {
            rflg = false;
            a = aa;
            b = bb;
            y0 = yy0;
        }

        const lgm = (yp * yp - 3.0) / 6.0;
        x = 2.0 / (1.0 / (2.0 * a - 1.0) + 1.0 / (2.0 * b - 1.0));
        var d = yp * math.sqrt(x + lgm) / x - (1.0 / (2.0 * b - 1.0) - 1.0 / (2.0 * a - 1.0)) * (lgm + 5.0 / 6.0 - 2.0 / (3.0 * x));
        d = 2.0 * d;
        if (d < MINLOG) {
            return done(rflg, 0.0); // Underflow
        }
        x = a / (a + b * math.exp(d));
        y = incbet(a, b, x);
        yp = (y - y0) / y0;
        if (math.fabs(yp) < 0.2) {
            state = .newton;
            break;
        }

        break;
    }

    var x0: f64 = 0;
    var yl: f64 = 0;
    var x1: f64 = 1;
    var yh: f64 = 1;
    var nflg = false;

    outer: while (true) {
        switch (state) {
            .ihalve => {
                var dir: f64 = 0;
                var di: f64 = 0.5;

                var i: usize = 0;
                while (i < 100) : (i += 1) {
                    if (i != 0) {
                        x = x0 + di * (x1 - x0);
                        if (x == 1.0) {
                            x = 1.0 - MACHEP;
                        }
                        if (x == 0.0) {
                            di = 0.5;
                            x = x0 + di * (x1 - x0);
                            if (x == 0.0) {
                                return done(rflg, 0.0); // Underflow
                            }
                        }
                        y = incbet(a, b, x);
                        yp = (x1 - x0) / (x1 + x0);
                        if (math.fabs(yp) < dithresh) {
                            state = .newton;
                            continue :outer;
                        }
                        yp = (y - y0) / y0;
                        if (math.fabs(yp) < dithresh) {
                            state = .newton;
                            continue :outer;
                        }
                    }
                    if (y < y0) {
                        x0 = x;
                        yl = y;
                        if (dir < 0) {
                            dir = 0;
                            di = 0.5;
                        } else if (dir > 3) {
                            di = 1.0 - (1.0 - di) * (1.0 - di);
                        } else if (dir > 1) {
                            di = 0.5 * di + 0.5;
                        } else {
                            di = (y0 - y) / (yh - yl);
                        }

                        dir += 1;
                        if (x0 > 0.75) {
                            if (rflg) {
                                rflg = false;
                                a = aa;
                                b = bb;
                                y0 = yy0;
                            } else {
                                rflg = true;
                                a = bb;
                                b = aa;
                                y0 = 1.0 - yy0;
                            }
                            x = 1.0 - x;
                            y = incbet(a, b, x);
                            x0 = 0.0;
                            yl = 0.0;
                            x1 = 1.0;
                            yh = 1.0;
                            state = .ihalve;
                            continue :outer;
                        }
                    } else {
                        x1 = x;
                        if (rflg and x1 < MACHEP) {
                            return done(rflg, 0.0);
                        }
                        yh = y;
                        if (dir > 0) {
                            dir = 0;
                            di = 0.5;
                        } else if (dir < -3) {
                            di = di * di;
                        } else if (dir < -1) {
                            di = 0.5 * di;
                        } else {
                            di = (y - y0) / (yh - yl);
                        }
                        dir -= 1;
                    }
                }

                // Partial Precision Loss

                if (x0 >= 1.0) {
                    x = 1.0 - MACHEP;
                    return done(rflg, x);
                }
                if (x <= 0.0) {
                    return done(rflg, 0.0); // Underflow
                }

                state = .newton;
            },

            .newton => {
                if (nflg) {
                    return done(rflg, x);
                }

                nflg = true;
                const lgm = lgam(a + b) - lgam(a) - lgam(b);

                var i: usize = 0;
                while (i < 8) : (i += 1) {
                    // Compute the function at this point.
                    if (i != 0) {
                        y = incbet(a, b, x);
                    }
                    if (y < yl) {
                        x = x0;
                        y = yl;
                    } else if (y > yh) {
                        x = x1;
                        y = yh;
                    } else if (y < y0) {
                        x0 = x;
                        yl = y;
                    } else {
                        x1 = x;
                        yh = y;
                    }

                    if (x == 1.0 or x == 0.0) {
                        break;
                    }

                    // Compute the derivative of the function at this point.
                    var d = (a - 1.0) * math.ln(x) + (b - 1.0) * math.ln(1.0 - x) + lgm;
                    if (d < MINLOG) {
                        return done(rflg, x);
                    }
                    if (d > MAXLOG) {
                        break;
                    }
                    d = math.exp(d);
                    // Compute the step to the next approximation of x.
                    d = (y - y0) / d;
                    var xt = x - d;
                    if (xt <= x0) {
                        y = (x - x0) / (x1 - x0);
                        xt = x0 + 0.5 * y * (x - x0);
                        if (xt <= 0.0) {
                            break;
                        }
                    }
                    if (xt >= x1) {
                        y = (x1 - x) / (x1 - x0);
                        xt = x1 - 0.5 * y * (x1 - x);
                        if (xt >= 1.0) {
                            break;
                        }
                    }
                    x = xt;
                    if (math.fabs(d / x) < 128.0 * MACHEP) {
                        return done(rflg, x);
                    }
                }

                // Did not converge.
                dithresh = 256.0 * MACHEP;
                state = .ihalve;
            },
        }
    }

    unreachable;
}

test "incbi" {
    const cases = [_][4]f64{
        [_]f64{ 1, 1, 0.8, 0.8 },
        [_]f64{ 1, 5, 0.8, 0.99968000000000001 },
        [_]f64{ 10, 10, 0.8, 0.99842087945083291 },
        [_]f64{ 10, 10, 0.1, 3.929882327128003e-06 },
        [_]f64{ 10, 2, 0.4, 0.00073400320000000028 },
        [_]f64{ 0.1, 0.2, 0.6, 0.69285678232066683 },
        [_]f64{ 1, 10, 0.7489, 0.99999900352334858 },
    };

    for (cases) |c| {
        var r = incbet(c[0], c[1], c[2]);
        expectApproxEqRel(r, c[3], epsilon);

        var ri = incbi(c[0], c[1], r);
        expectApproxEqRel(ri, c[2], epsilon);
    }
}

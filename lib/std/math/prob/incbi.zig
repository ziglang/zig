// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.8:  June, 2000
// Copyright 1984, 1996, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;

usingnamespace @import("constants.zig");

const ndtri = math.prob.ndtri;
const lgam = math.prob.lgam;

fn done(rflg: bool, x: f64) f64 {
    if (rflg) {
        if (x <= MACHEP) {
            return 1.0 - MACHEP;
        } else {
            return 1.0 - x;
        }
    }

    return x;
}

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

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e-10;
const incbet = std.math.prob.incbet;

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

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
const prob = std.math.prob;
const gamma = prob.gamma;
const lnGamma = prob.lnGamma;
const airy = prob.airy;
const polevl = prob.polevl;
const p1evl = prob.p1evl;

const C = @import("constants.zig");

const MAXGAM = 34.84425627277176174;
const BIG = 1.44115188075855872E+17;
const big = BIG;

/// Bessel function of noninteger order
///
/// Returns Bessel function of order v of the argument,
/// where v is real.  Negative x is allowed if v is an integer.
///
/// Several expansions are included: the ascending power
/// series, the Hankel expansion, and two transitional
/// expansions for large v.  If v is not too large, it
/// is reduced by recurrence to a region of best accuracy.
/// The transitional expansions give 12D accuracy for v > 500.
///
///
/// ACCURACY:
/// Results for integer v are indicated by *, where x and v
/// both vary from -125 to +125.  Otherwise,
/// x ranges from 0 to 125, v ranges as indicated by "domain."
/// Error criterion is absolute, except relative when |besselj()| > 1.
///
/// arithmetic  v domain  x domain    # trials      peak       rms
///    IEEE      0,125     0,125      100000      4.6e-15    2.2e-16
///    IEEE   -125,0       0,125       40000      5.4e-11    3.7e-13
///    IEEE      0,500     0,500       20000      4.4e-15    4.0e-16
/// Integer v:
///    IEEE   -125,125   -125,125      50000      3.5e-15*   1.9e-16*
pub fn besselj(n_: f64, x_: f64) f64 {
    var n = n_;
    var x = x_;

    var nint = false; // Flag for integer n
    var sign: f64 = 1; // Flag for sign inversion
    var an = math.fabs(n);
    var y = math.floor(an);

    if (y == an) {
        nint = true;
        var i: isize = @intFromFloat(an - 16384.0 * math.floor(an / 16384.0));
        if (n < 0.0) {
            if (i & 1 != 0) {
                sign = -sign;
            }
            n = an;
        }
        if (x < 0.0) {
            if (i & 1 != 0) {
                sign = -sign;
            }
            x = -x;
        }
        if (n == 0.0) {
            return prob.besselj0(x);
        }
        if (n == 1.0) {
            return sign * prob.besselj1(x);
        }
    }

    if (x < 0.0 and y != an) {
        y = 0.0;
        return sign * y; // Domain
    }

    y = math.fabs(x);
    if (y < C.MACHEP) {
        y = 0.0;
        return sign * y; // Underflow
    }

    var k = 3.6 * math.sqrt(y);
    var t = 3.6 * math.sqrt(an);
    if (y < t and an > 21.0) {
        return sign * jvs(n, x);
    }
    if (an < k and y > 21.0) {
        return sign * hankel(n, x);
    }

    if (an < 500.0) {
        var q: f64 = undefined;

        // Note: if x is too large, the continued
        // fraction will fail; but then the
        // Hankel expansion can be used.
        if (nint) {
            k = 0.0;
            q = recur(&n, x, &k, true);

            if (k == 0.0) {
                y = prob.besselj0(x) / q;
                return sign * y;
            }

            if (k == 1.0) {
                y = prob.besselj1(x) / q;
                return sign * y;
            }
        }

        if (n >= 0.0 and n < 20.0 and y > 6.0 and y < 20.0 or (an > 2.0 * y)) {
            // Recur backwards from a larger value of n
            k = n;

            y = y + an + 1.0;
            if (y < 30.0) {
                y = 30.0;
            }
            y = n + math.floor(y - n);
            q = recur(&y, x, &k, false);
            y = jvs(y, x) * q;
            return sign * y;
        }

        if (k <= 30.0) {
            k = 2.0;
        } else if (k < 90.0) {
            k = (3 * k) / 4;
        }

        if (an > (k + 3.0)) {
            if (n < 0.0)
                k = -k;
            q = n - math.floor(n);
            k = math.floor(k) + q;
            if (n > 0.0) {
                q = recur(&n, x, &k, true);
            } else {
                t = k;
                k = n;
                q = recur(&t, x, &k, true);
                k = t;
            }
            if (q == 0.0) {
                // underflow
                y = 0.0;
                return sign * y;
            }
        } else {
            k = n;
            q = 1.0;
        }

        // boundary between convergence of
        // power series and Hankel expansion
        y = math.fabs(k);
        if (y < 26.0) {
            t = (0.0083 * y + 0.09) * y + 12.9;
        } else {
            t = 0.9 * y;
        }

        if (x > t) {
            y = hankel(k, x);
        } else {
            y = jvs(k, x);
        }

        if (n > 0.0) {
            y /= q;
        } else {
            y *= q;
        }
    } else {
        // For large n, use the uniform expansion
        // or the transitional expansion.
        // But if x is of the order of n**2,
        // these may blow up, whereas the
        // Hankel expansion will then work.
        if (n < 0.0) {
            y = 0.0;
            return sign * y; // TotalPrecisionLoss
        }

        t = x / n;
        t /= n;
        if (t > 0.3) {
            y = hankel(n, x);
        } else {
            y = jnx(n, x);
        }
    }

    return sign * y;
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 0.000001;

test "besselj" {
    expectApproxEqRel(besselj(1.5, 0), 0, epsilon);
    expectApproxEqRel(besselj(1.5, 1), 0.240297839123, epsilon);
    expectApproxEqRel(besselj(1.5, 1.5), 0.387142217276067, epsilon);
    expectApproxEqRel(besselj(-1.5, 1.5), -0.6805601853491455, epsilon);
}

// Reduce the order by backward recurrence.
// AMS55 #9.1.27 and 9.1.73.
fn recur(n: *f64, x: f64, newn: *f64, cancel: bool) f64 {
    // continued fraction for Jn(x)/Jn-1(x)
    var nflag: f64 = if (n.* < 0.0) 1 else 0;
    var ans: f64 = 1.0;

    fstart: while (true) {
        var pkm2: f64 = 0;
        var qkm2: f64 = 1;
        var pkm1 = x;
        var qkm1 = n.* + n.*;
        var xk = -x * x;
        var yk = qkm1;
        var ctr: isize = 0;

        // mimic do-while
        while (true) {
            yk += 2.0;
            var pk = pkm1 * yk + pkm2 * xk;
            var qk = qkm1 * yk + qkm2 * xk;
            pkm2 = pkm1;
            pkm1 = pk;
            qkm2 = qkm1;
            qkm1 = qk;

            var r = if (qk != 0) pk / qk else 0.0;

            const t = blk: {
                if (r != 0) {
                    const tv = math.fabs((ans - r) / r);
                    ans = r;
                    break :blk tv;
                } else {
                    break :blk 1.0;
                }
            };

            ctr += 1;
            if (ctr > 1000) {
                break; // Underflow
            }
            if (t < C.MACHEP) {
                break;
            }

            if (math.fabs(pk) > big) {
                pkm2 /= big;
                pkm1 /= big;
                qkm2 /= big;
                qkm1 /= big;
            }

            if (t <= C.MACHEP) break;
        }

        // Change n to n-1 if n < 0 and the continued fraction is small
        if (nflag > 0) {
            if (math.fabs(ans) < 0.125) {
                nflag = -1;
                n.* = n.* - 1.0;
                continue :fstart;
            }
        }

        break;
    }

    var kf = newn.*;

    // backward recurrence
    //              2k
    //  J   (x)  =  --- J (x)  -  J   (x)
    //   k-1         x   k         k+1
    var pk: f64 = 1.0;
    var pkm1 = 1.0 / ans;
    var k = n.* - 1.0;
    var r = 2 * k;

    var pkm2: f64 = undefined;

    // mimic do-while
    while (true) {
        pkm2 = (pkm1 * r - pk * x) / x;
        // pkp1 = pk;
        pk = pkm1;
        pkm1 = pkm2;
        r -= 2.0;
        k -= 1.0;

        if (k <= (kf + 0.5)) break;
    }

    // Take the larger of the last two iterates
    // on the theory that it may have less cancellation error.
    if (cancel) {
        if (kf >= 0.0 and math.fabs(pk) > math.fabs(pkm1)) {
            k += 1.0;
            pkm2 = pk;
        }
    }

    newn.* = k;
    return pkm2;
}

// Ascending power series for Jv(x).
// AMS55 #9.1.10.
fn jvs(n: f64, x: f64) f64 {
    var sgngam: f64 = -1;
    var z: f64 = -x * x / 4.0;
    var u: f64 = 1;
    var y: f64 = u;
    var k: f64 = 1;
    var t: f64 = 1;

    while (t > C.MACHEP) {
        u *= z / (k * (n + k));
        y += u;
        k += 1.0;
        if (y != 0) {
            t = math.fabs(u / y);
        }
    }

    const frr = math.frexp(0.5 * x);
    t = frr.significand;
    var ex: f64 = @floatFromInt(frr.exponent);
    ex = ex * n;
    if (ex > -1023 and ex < 1023 and n > 0.0 and n < (MAXGAM - 1.0)) {
        t = math.pow(f64, 0.5 * x, n) / gamma(n + 1.0);
        y *= t;
    } else {
        t = n * math.ln(0.5 * x) - lnGamma(n + 1.0);
        if (y < 0) {
            sgngam = -sgngam;
            y = -y;
        }

        t += math.ln(y);
        if (t < -C.MAXLOG) {
            return 0.0;
        }
        if (t > C.MAXLOG) {
            return math.inf(f64); // Overflow
        }
        y = sgngam * math.exp(t);
    }

    return y;
}

// Hankel's asymptotic expansion
// for large x.
// AMS55 #9.2.5.
fn hankel(n: f64, x: f64) f64 {
    var m: f64 = 4 * n * n;
    var j: f64 = 1;
    var z: f64 = 8 * x;
    var k: f64 = 1;
    var p: f64 = 1;
    var u = (m - 1.0) / z;
    var q: f64 = u;
    var sign: f64 = 1;
    var conv: f64 = 1;
    var t: f64 = 1;
    var pp: f64 = 1e38;
    var qq: f64 = 1e38;
    var flag = false;

    while (t > C.MACHEP) {
        k += 2.0;
        j += 1.0;
        sign = -sign;
        u *= (m - k * k) / (j * z);
        p += sign * u;
        k += 2.0;
        j += 1.0;
        u *= (m - k * k) / (j * z);
        q += sign * u;
        t = math.fabs(u / p);

        if (t < conv) {
            conv = t;
            qq = q;
            pp = p;
            flag = true;
        }

        // stop if the terms start getting larger
        if (flag and t > conv) {
            break;
        }
    }

    u = x - (0.5 * n + 0.25) * PI;
    t = math.sqrt(2.0 / (PI * x)) * (pp * math.cos(u) - qq * math.sin(u));
    return t;
}

const lambda = [_]f64{
    1.0,                           1.041666666666666666666667E-1,
    8.355034722222222222222222E-2, 1.282265745563271604938272E-1,
    2.918490264641404642489712E-1, 8.816272674437576524187671E-1,
    3.321408281862767544702647E+0, 1.499576298686255465867237E+1,
    7.892301301158651813848139E+1, 4.744515388682643231611949E+2,
    3.207490090890661934704328E+3,
};

const mu = [_]f64{
    1.0,                            -1.458333333333333333333333E-1,
    -9.874131944444444444444444E-2, -1.433120539158950617283951E-1,
    -3.172272026784135480967078E-1, -9.424291479571202491373028E-1,
    -3.511203040826354261542798E+0, -1.572726362036804512982712E+1,
    -8.228143909718594444224656E+1, -4.923553705236705240352022E+2,
    -3.316218568547972508762102E+3,
};

const P1 = [_]f64{
    -2.083333333333333333333333E-1, 1.250000000000000000000000E-1,
};

const P2 = [_]f64{
    3.342013888888888888888889E-1, -4.010416666666666666666667E-1,
    7.031250000000000000000000E-2,
};

const P3 = [_]f64{
    -1.025812596450617283950617E+0, 1.846462673611111111111111E+0,
    -8.912109375000000000000000E-1, 7.324218750000000000000000E-2,
};

const P4 = [_]f64{
    4.669584423426247427983539E+0, -1.120700261622299382716049E+1,
    8.789123535156250000000000E+0, -2.364086914062500000000000E+0,
    1.121520996093750000000000E-1,
};

const P5 = [_]f64{
    -2.8212072558200244877E1, 8.4636217674600734632E1,
    -9.1818241543240017361E1, 4.2534998745388454861E1,
    -7.3687943594796316964E0, 2.27108001708984375E-1,
};

const P6 = [_]f64{
    2.1257013003921712286E2,  -7.6525246814118164230E2,
    1.0599904525279998779E3,  -6.9957962737613254123E2,
    2.1819051174421159048E2,  -2.6491430486951555525E1,
    5.7250142097473144531E-1,
};

const P7 = [_]f64{
    -1.9194576623184069963E3, 8.0617221817373093845E3,
    -1.3586550006434137439E4, 1.1655393336864533248E4,
    -5.3056469786134031084E3, 1.2009029132163524628E3,
    -1.0809091978839465550E2, 1.7277275025844573975E0,
};

// Asymptotic expansion for large n.
// AMS55 #9.3.35.
fn jnx(n: f64, x: f64) f64 {
    // Test for x very close to n.
    // Use expansion for transition region if so.
    var cbn = math.cbrt(n);
    var z = (x - n) / cbn;
    if (math.fabs(z) <= 0.7) {
        return jnt(n, x);
    }

    z = x / n;
    var zz = 1.0 - z * z;
    if (zz == 0.0) {
        return 0.0;
    }

    var nflg: f64 = 1;
    var sz: f64 = undefined;
    var t: f64 = undefined;
    var zeta: f64 = undefined;
    if (zz > 0.0) {
        sz = math.sqrt(zz);
        t = 1.5 * (math.ln((1.0 + sz) / z) - sz); // zeta ** 3/2
        zeta = math.cbrt(t * t);
        nflg = 1;
    } else {
        sz = math.sqrt(-zz);
        t = 1.5 * (sz - math.acos(1.0 / z));
        zeta = -math.cbrt(t * t);
        nflg = -1;
    }

    var z32i = math.fabs(1.0 / t);
    var sqz = math.cbrt(t);

    // Airy function
    var n23 = math.cbrt(n * n);
    t = n23 * zeta;

    const ar = airy(t);

    // polynomials in expansion
    var zzi = 1.0 / zz;
    var pp1 = zz * zz;
    var pp2 = pp1 * zz;

    var u = [8]f64{
        1.0,
        polevl(zzi, P1[0..1]) / sz,
        polevl(zzi, P2[0..2]) / zz,
        polevl(zzi, P3[0..3]) / (sz * zz),
        polevl(zzi, P4[0..4]) / pp1,
        polevl(zzi, P5[0..5]) / (pp1 * sz),
        polevl(zzi, P6[0..6]) / pp2,
        polevl(zzi, P7[0..7]) / (pp2 * sz),
    };

    var pp: f64 = 0.0;
    var qq: f64 = 0.0;
    var np: f64 = 1.0;
    // flags to stop when terms get larger
    var doa = true;
    var dob = true;
    var akl: f64 = C.MAXNUM;
    var bkl: f64 = C.MAXNUM;
    var sign: f64 = 1;

    var k: usize = 0;
    while (k <= 3) : (k += 1) {
        var tk = 2 * k;
        var tkp1 = tk + 1;
        var zp: f64 = 1.0;
        var ak: f64 = 0.0;
        var bk: f64 = 0.0;

        var s: usize = 0;
        while (s <= tk) : (s += 1) {
            if (doa) {
                if ((s & 3) > 1) {
                    sign = nflg;
                } else {
                    sign = 1;
                }
                ak += sign * mu[s] * zp * u[tk - s];
            }

            if (dob) {
                var m = tkp1 - s;
                if (((m + 1) & 3) > 1) {
                    sign = nflg;
                } else {
                    sign = 1;
                }
                bk += sign * lambda[s] * zp * u[m];
            }
            zp *= z32i;
        }

        if (doa) {
            ak *= np;
            t = math.fabs(ak);
            if (t < akl) {
                akl = t;
                pp += ak;
            } else {
                doa = false;
            }
        }

        if (dob) {
            bk += lambda[tkp1] * zp * u[0];
            bk *= -np / sqz;
            t = math.fabs(bk);
            if (t < bkl) {
                bkl = t;
                qq += bk;
            } else {
                dob = false;
            }
        }

        if (np < MACHEP) {
            break;
        }

        np /= n * n;
    }

    // normalizing factor ( 4*zeta/(1 - z**2) )**1/4
    t = 4.0 * zeta / zz;
    t = math.sqrt(math.sqrt(t));

    t *= ar.ai * pp / math.cbrt(n) + ar.aip * qq / (n23 * n);
    return t;
}

const PF2 = [_]f64{
    -9.0000000000000000000e-2, 8.5714285714285714286e-2,
};

const PF3 = [_]f64{
    1.3671428571428571429e-1,  -5.4920634920634920635e-2,
    -4.4444444444444444444e-3,
};

const PF4 = [_]f64{
    1.3500000000000000000e-3, -1.6036054421768707483e-1,
    4.2590187590187590188e-2, 2.7330447330447330447e-3,
};

const PG1 = [_]f64{
    -2.4285714285714285714e-1, 1.4285714285714285714e-2,
};

const PG2 = [_]f64{
    -9.0000000000000000000e-3, 1.9396825396825396825e-1,
    -1.1746031746031746032e-2,
};

const PG3 = [_]f64{
    1.9607142857142857143e-2, -1.5983694083694083694e-1,
    6.3838383838383838384e-3,
};

// Asymptotic expansion for transition region,
// n large and x close to n.
// AMS55 #9.3.23.
fn jnt(n: f64, x: f64) f64 {
    var cbn = math.cbrt(n);
    var z = (x - n) / cbn;
    var cbtwo = math.cbrt(@as(f64, 2.0)); // TODO lift to constants?

    // Airy function
    var zz = -cbtwo * z;

    const ar = airy(zz);

    // polynomials in expansion
    zz = z * z;
    var z3 = zz * z;

    const F = [5]f64{
        1.0,
        -z / 5.0,
        polevl(z3, PF2[0..1]) * zz,
        polevl(z3, PF3[0..2]),
        polevl(z3, PF4[0..3]) * z,
    };

    const G = [4]f64{
        0.3 * zz,
        polevl(z3, PG1[0..1]),
        polevl(z3, PG2[0..2]) * z,
        polevl(z3, PG3[0..2]) * zz,
    };

    var pp: f64 = 0.0;
    var qq: f64 = 0.0;
    var nk: f64 = 1.0;
    var n23 = math.cbrt(n * n);

    var k: usize = 0;
    while (k <= 4) : (k += 1) {
        var fk = F[k] * nk;
        pp += fk;
        if (k != 4) {
            var gk = G[k] * nk;
            qq += gk;
        }
        nk /= n23;
    }

    var fk = cbtwo * ar.ai * pp / cbn + math.cbrt(@as(f64, 4.0)) * ar.aip * qq / n;
    return fk;
}

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
// Cephes Math Library Release 2.8:  June, 2000
// Copyright 1984, 1987, 1989, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;
const polevl = math.prob.polevl;
const p1evl = math.prob.p1evl;

usingnamespace @import("constants.zig");

// Note: all coefficients satisfy the relative error criterion
// except YP, YQ which are designed for absolute error.

const PP = [_]f64{
    7.96936729297347051624E-4, 8.28352392107440799803E-2,
    1.23953371646414299388E0,  5.44725003058768775090E0,
    8.74716500199817011941E0,  5.30324038235394892183E0,
    9.99999999999999997821E-1,
};

const PQ = [_]f64{
    9.24408810558863637013E-4, 8.56288474354474431428E-2,
    1.25352743901058953537E0,  5.47097740330417105182E0,
    8.76190883237069594232E0,  5.30605288235394617618E0,
    1.00000000000000000218E0,
};

const QP = [_]f64{
    -1.13663838898469149931E-2, -1.28252718670509318512E0,
    -1.95539544257735972385E1,  -9.32060152123768231369E1,
    -1.77681167980488050595E2,  -1.47077505154951170175E2,
    -5.14105326766599330220E1,  -6.05014350600728481186E0,
};

const QQ = [_]f64{
    6.43178256118178023184E1, 8.56430025976980587198E2,
    3.88240183605401609683E3, 7.24046774195652478189E3,
    5.93072701187316984827E3, 2.06209331660327847417E3,
    2.42005740240291393179E2,
};

const YP = [_]f64{
    1.55924367855235737965E4,  -1.46639295903971606143E7,
    5.43526477051876500413E9,  -9.82136065717911466409E11,
    8.75906394395366999549E13, -3.46628303384729719441E15,
    4.42733268572569800351E16, -1.84950800436986690637E16,
};

const YQ = [_]f64{
    1.04128353664259848412E3,  6.26107330137134956842E5,
    2.68919633393814121987E8,  8.64002487103935000337E10,
    2.02979612750105546709E13, 3.17157752842975028269E15,
    2.50596256172653059228E17,
};

const RP = [_]f64{
    -4.79443220978201773821E9,  1.95617491946556577543E12,
    -2.49248344360967716204E14, 9.70862251047306323952E15,
};

const RQ = [_]f64{
    4.99563147152651017219E2,  1.73785401676374683123E5,
    4.84409658339962045305E7,  1.11855537045356834862E10,
    2.11277520115489217587E12, 3.10518229857422583814E14,
    3.18121955943204943306E16, 1.71086294081043136091E18,
};

const DR1 = 5.78318596294678452118E0;
const DR2 = 3.04712623436620863991E1;

/// Bessel function of order zero
///
/// Returns Bessel function of order zero of the argument.
///
/// The domain is divided into the intervals [0, 5] and
/// (5, infinity). In the first interval the following rational
/// approximation is used:
///
///
///        2         2
/// (w - r  ) (w - r  ) P (w) / Q (w)
///       1         2    3       8
///
///            2
/// where w = x  and the two r's are zeros of the function.
///
/// In the second interval, the Hankel asymptotic expansion
/// is employed with two rational functions of degree 6/6
/// and 7/7.
///
///
/// ACCURACY:
///
///                      Absolute error:
/// arithmetic   domain     # trials      peak         rms
///    IEEE      0, 30       60000       4.2e-16     1.1e-16
pub fn besselj0(x_: f64) f64 {
    const x = if (x_ < 0) -x_ else x_;

    if (x <= 5.0) {
        const z = x * x;
        if (x < 1.0e-5) {
            return 1.0 - z / 4.0;
        }

        const p = (z - DR1) * (z - DR2);
        return p * polevl(z, RP[0..]) / p1evl(z, RQ[0..]);
    }

    const w = 5.0 / x;
    var q = 25.0 / (x * x);
    var p = polevl(q, PP[0..]) / polevl(q, PQ[0..]);
    q = polevl(q, QP[0..]) / p1evl(q, QQ[0..]);
    const xn = x - PIO4;
    p = p * math.cos(xn) - w * q * math.sin(xn);
    return p * SQ2OPI / math.sqrt(x);
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e-10;

test "besselj0" {
    const cases = [_][2]f64{
        [_]f64{ 0, 1 },
        [_]f64{ 1, 0.765197686558 },
        [_]f64{ -1, 0.765197686558 },
        [_]f64{ 1.3, 0.6200859895615 },
        [_]f64{ 3.141, -0.30407343000 },
    };

    for (cases) |c| {
        expectApproxEqRel(besselj0(c[0]), c[1], epsilon);
    }
}

/// Bessel function of the second kind, order zero
///
/// Returns Bessel function of the second kind, of order
/// zero, of the argument.
///
/// The domain is divided into the intervals [0, 5] and
/// (5, infinity). In the first interval a rational approximation
/// R(x) is employed to compute
///   bessely0(x)  = R(x)  +   2 * log(x) * besselj0(x) / PI.
/// Thus a call to besselj0() is required.
///
/// In the second interval, the Hankel asymptotic expansion
/// is employed with two rational functions of degree 6/6
/// and 7/7.
///
/// Rational approximation coefficients YP[], YQ[] are used here.
/// The function computed is  bessely0(x)  -  2 * log(x) * besselj0(x) / PI,
/// whose value at x = 0 is  2 * ( log(0.5) + EUL ) / PI
/// = 0.073804295108687225.
///
/// ACCURACY:
///
///  Absolute error, when bessely0(x) < 1; else relative error:
///
/// arithmetic   domain     # trials      peak         rms
///    DEC       0, 30        9400       7.0e-17     7.9e-18
///    IEEE      0, 30       30000       1.3e-15     1.6e-16
///
pub fn bessely0(x: f64) f64 {
    if (x <= 0.0) {
        return -math.inf(f64); // Domain
    }

    if (x <= 5.0) {
        const z = x * x;
        const w = polevl(z, YP[0..]) / p1evl(z, YQ[0..]);
        return w + TWOOPI * math.ln(x) * besselj0(x);
    }

    const w = 5.0 / x;
    const z = 25.0 / (x * x);
    var p = polevl(z, PP[0..]) / polevl(z, PQ[0..]);
    const q = polevl(z, QP[0..]) / p1evl(z, QQ[0..]);
    const xn = x - PIO4;
    p = p * math.sin(xn) + w * q * math.cos(xn);
    return p * SQ2OPI / math.sqrt(x);
}

test "bessely0" {
    const cases = [_][2]f64{
        [_]f64{ 1, 0.088256964215677 },
        [_]f64{ 1.3, 0.28653535716557 },
        [_]f64{ 3.141, 0.328578958219224 },
    };

    expect(math.isNegativeInf(bessely0(0)));

    for (cases) |c| {
        expectApproxEqRel(bessely0(c[0]), c[1], epsilon);
    }
}

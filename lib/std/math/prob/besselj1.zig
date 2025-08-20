// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.8:  June, 2000
// Copyright 1984, 1987, 1989, 2000 by Stephen L. Moshier

const std = @import("../../std.zig");
const math = std.math;
const polevl = math.prob.polevl;
const p1evl = math.prob.p1evl;

const C = @import("constants.zig");

const RP = [_]f64{
    -8.99971225705559398224E8,  4.52228297998194034323E11,
    -7.27494245221818276015E13, 3.68295732863852883286E15,
};

const RQ = [_]f64{
    6.20836478118054335476E2,  2.56987256757748830383E5,
    8.35146791431949253037E7,  2.21511595479792499675E10,
    4.74914122079991414898E12, 7.84369607876235854894E14,
    8.95222336184627338078E16, 5.32278620332680085395E18,
};

const PP = [_]f64{
    7.62125616208173112003E-4, 7.31397056940917570436E-2,
    1.12719608129684925192E0,  5.11207951146807644818E0,
    8.42404590141772420927E0,  5.21451598682361504063E0,
    1.00000000000000000254E0,
};
const PQ = [_]f64{
    5.71323128072548699714E-4, 6.88455908754495404082E-2,
    1.10514232634061696926E0,  5.07386386128601488557E0,
    8.39985554327604159757E0,  5.20982848682361821619E0,
    9.99999999999999997461E-1,
};

const QP = [_]f64{
    5.10862594750176621635E-2, 4.98213872951233449420E0,
    7.58238284132545283818E1,  3.66779609360150777800E2,
    7.10856304998926107277E2,  5.97489612400613639965E2,
    2.11688757100572135698E2,  2.52070205858023719784E1,
};

const QQ = [_]f64{
    7.42373277035675149943E1, 1.05644886038262816351E3,
    4.98641058337653607651E3, 9.56231892404756170795E3,
    7.99704160447350683650E3, 2.82619278517639096600E3,
    3.36093607810698293419E2,
};

const YP = [_]f64{
    1.26320474790178026440E9,  -6.47355876379160291031E11,
    1.14509511541823727583E14, -8.12770255501325109621E15,
    2.02439475713594898196E17, -7.78877196265950026825E17,
};

const YQ = [_]f64{
    5.94301592346128195359E2,  2.35564092943068577943E5,
    7.34811944459721705660E7,  1.87601316108706159478E10,
    3.88231277496238566008E12, 6.20557727146953693363E14,
    6.87141087355300489866E16, 3.97270608116560655612E18,
};

const Z1 = 1.46819706421238932572E1;
const Z2 = 4.92184563216946036703E1;

/// Bessel function of order one
///
/// Returns Bessel function of order one of the argument.
///
/// The domain is divided into the intervals [0, 8] and
/// (8, infinity). In the first interval a 24 term Chebyshev
/// expansion is used. In the second, the asymptotic
/// trigonometric representation is employed using two
/// rational functions of degree 5/5.
///
///
/// ACCURACY:
///
///                      Absolute error:
/// arithmetic   domain      # trials      peak         rms
///    IEEE      0, 30       30000       2.6e-16     1.1e-16
pub fn besselj1(x: f64) f64 {
    var w = if (x < 0) -x else x;

    if (w <= 5.0) {
        const z = x * x;
        w = polevl(z, RP[0..]) / p1evl(z, RQ[0..]);
        w = w * x * (z - Z1) * (z - Z2);
        return w;
    }

    w = 5.0 / x;
    const z = w * w;
    var p = polevl(z, PP[0..]) / polevl(z, PQ[0..]);
    const q = polevl(z, QP[0..]) / p1evl(z, QQ[0..]);
    const xn = x - C.THPIO4;
    p = p * math.cos(xn) - w * q * math.sin(xn);
    return p * C.SQ2OPI / math.sqrt(x);
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e-10;

test "besselj1" {
    const cases = [_][2]f64{
        [_]f64{ 0, 0 },
        [_]f64{ 1, 0.4400505857449336 },
        [_]f64{ -1, -0.4400505857449336 },
        [_]f64{ 1.3, 0.52202324741466 },
        [_]f64{ 3.141, 0.2848493225113 },
    };

    for (cases) |c| {
        expectApproxEqRel(besselj1(c[0]), c[1], epsilon);
    }
}

/// Bessel function of second kind of order one
///
/// Returns Bessel function of the second kind of order one
/// of the argument.
///
/// The domain is divided into the intervals [0, 8] and
/// (8, infinity). In the first interval a 25 term Chebyshev
/// expansion is used, and a call to besselj1() is required.
/// In the second, the asymptotic trigonometric representation
/// is employed using two rational functions of degree 5/5.
///
///
/// ACCURACY:
///
///                      Absolute error:
/// arithmetic   domain      # trials      peak         rms
///    IEEE      0, 30       30000       1.0e-15     1.3e-16
///
/// (error criterion relative when |y1| > 1).
pub fn bessely1(x: f64) f64 {
    if (x <= 0.0) {
        return -math.inf(f64); // Domain Error
    }

    if (x <= 5.0) {
        const z = x * x;
        var w = x * (polevl(z, YP[0..]) / p1evl(z, YQ[0..]));
        w += C.TWOOPI * (besselj1(x) * math.ln(x) - 1.0 / x);
        return w;
    }

    const w = 5.0 / x;
    const z = w * w;
    var p = polevl(z, PP[0..]) / polevl(z, PQ[0..]);
    const q = polevl(z, QP[0..]) / p1evl(z, QQ[0..]);
    const xn = x - C.THPIO4;
    p = p * math.sin(xn) + w * q * math.cos(xn);
    return p * C.SQ2OPI / math.sqrt(x);
}

test "y1" {
    const cases = [_][2]f64{
        [_]f64{ 1, -0.781212821300288717 },
        [_]f64{ 1.3, -0.548519729980776 },
        [_]f64{ 3.141, 0.3587459411754785 },
    };

    expect(math.isNegativeInf(bessely1(0)));

    for (cases) |c| {
        expectApproxEqRel(bessely1(c[0]), c[1], epsilon);
    }
}

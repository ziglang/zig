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

usingnamespace @import("constants.zig");

// sqrt(2pi)
const s2pi = 2.50662827463100050242E0;

// approximation for 0 <= |y - 0.5| <= 3/8
const P0 = [_]f64{
    -5.99633501014107895267E1, 9.80010754185999661536E1,
    -5.66762857469070293439E1, 1.39312609387279679503E1,
    -1.23916583867381258016E0,
};

const Q0 = [_]f64{
    1.95448858338141759834E0, 4.67627912898881538453E0,
    8.63602421390890590575E1, -2.25462687854119370527E2,
    2.00260212380060660359E2, -8.20372256168333339912E1,
    1.59056225126211695515E1, -1.18331621121330003142E0,
};

// Approximation for interval z = sqrt(-2 log y ) between 2 and 8
// i.e., y between exp(-2) = .135 and exp(-32) = 1.27e-14.
const P1 = [_]f64{
    4.05544892305962419923E0,   3.15251094599893866154E1,
    5.71628192246421288162E1,   4.40805073893200834700E1,
    1.46849561928858024014E1,   2.18663306850790267539E0,
    -1.40256079171354495875E-1, -3.50424626827848203418E-2,
    -8.57456785154685413611E-4,
};

const Q1 = [_]f64{
    1.57799883256466749731E1,   4.53907635128879210584E1,
    4.13172038254672030440E1,   1.50425385692907503408E1,
    2.50464946208309415979E0,   -1.42182922854787788574E-1,
    -3.80806407691578277194E-2, -9.33259480895457427372E-4,
};

// Approximation for interval z = sqrt(-2 log y ) between 8 and 64
// i.e., y between exp(-32) = 1.27e-14 and exp(-2048) = 3.67e-890.
const P2 = [_]f64{
    3.23774891776946035970E0,  6.91522889068984211695E0,
    3.93881025292474443415E0,  1.33303460815807542389E0,
    2.01485389549179081538E-1, 1.23716634817820021358E-2,
    3.01581553508235416007E-4, 2.65806974686737550832E-6,
    6.23974539184983293730E-9,
};

const Q2 = [_]f64{
    6.02427039364742014255E0,  3.67983563856160859403E0,
    1.37702099489081330271E0,  2.16236993594496635890E-1,
    1.34204006088543189037E-2, 3.28014464682127739104E-4,
    2.89247864745380683936E-6, 6.79019408009981274425E-9,
};

/// Inverse of Normal distribution function
///
/// Returns the argument, x, for which the area under the
/// Gaussian probability density function (integrated from
/// minus infinity to x) is equal to y.
///
///
/// For small arguments 0 < y < exp(-2), the program computes
/// z = sqrt( -2.0 * log(y) );  then the approximation is
/// x = z - log(z)/z  - (1/z) P(1/z) / Q(1/z).
/// There are two rational functions P/Q, one for 0 < y < exp(-32)
/// and the other for y up to exp(-2).  For larger arguments,
/// w = y - 0.5, and  x/sqrt(2pi) = w + w**3 R(w**2)/S(w**2)).
///
///
/// ACCURACY:
///
///                      Relative error:
/// arithmetic   domain        # trials      peak         rms
///    DEC      0.125, 1         5500       9.5e-17     2.1e-17
///    DEC      6e-39, 0.135     3500       5.7e-17     1.3e-17
///    IEEE     0.125, 1        20000       7.2e-16     1.3e-16
///    IEEE     3e-308, 0.135   50000       4.6e-16     9.8e-17
///
///
/// ERROR MESSAGES:
///
///   message         condition    value returned
/// ndtri domain       x <= 0        -inf
/// ndtri domain       x >= 1         inf
pub fn ndtri(y0: f64) f64 {
    if (y0 <= 0.0) {
        return -math.inf(f64); // Domain error
    }

    if (y0 >= 1.0) {
        return math.inf(f64); // Domain error
    }

    var code = true;

    var y = y0;
    // 0.135... = exp(-2) */
    if (y > 1.0 - 0.13533528323661269189) {
        y = 1.0 - y;
        code = false;
    }

    if (y > 0.13533528323661269189) {
        y = y - 0.5;
        var y2 = y * y;
        var x = y + y * (y2 * polevl(y2, P0[0..]) / p1evl(y2, Q0[0..]));
        x = x * s2pi;
        return x;
    }

    var x = math.sqrt(-2.0 * math.ln(y));
    var x0 = x - math.ln(x) / x;

    var z = 1.0 / x;

    // y > exp(-32) = 1.2664165549e-14
    const x1 = if (x < 8.0)
        z * polevl(z, P1[0..]) / p1evl(z, Q1[0..])
    else
        z * polevl(z, P2[0..]) / p1evl(z, Q2[0..]);

    x = x0 - x1;
    if (!code) {
        x = -x;
    }

    return x;
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e5;

test "ndtri" {
    expectApproxEqRel(ndtri(7.62e-24), 10, epsilon);
    expectApproxEqRel(ndtri(0.1587), -1, epsilon);
    expectApproxEqRel(ndtri(0.5), 0, epsilon);
    expectApproxEqRel(ndtri(0.8413), 1, epsilon);
    expectApproxEqRel(ndtri(1 - 2.867e-7), 5, epsilon);
}

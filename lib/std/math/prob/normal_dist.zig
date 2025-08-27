// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
// Cephes Math Library Release 2.9:  November, 2000
// Copyright 1984, 1987, 1988, 1992, 2000 by Stephen L. Moshier

const std = @import("std");
const math = std.math;

const C = @import("constants.zig");

const polevl = math.prob.polevl;
const p1evl = math.prob.p1evl;
const expx2 = @import("expx2.zig").expx2;

// Define this macro to suppress error propagation in exp(x^2)
// by using the expx2 function.  The tradeoff is that doing so
// generates two calls to the exponential function instead of one.  */
const USE_EXPXSQ = false;
// TODO: figure out if USE_EXPXSQ actually does anything

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
///       f(x)  = ---------    |    exp( - t /2 ) dt
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
pub fn normalDist(a: f64) f64 {
    const x = a * math.sqrt1_2;
    var z = @abs(x);

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

test "normalDist" {
    const e2 = 1e-3; // TODO: Get more accurate reference

    try expectApproxEqRel(normalDist(-10), 7.62e-24, e2);
    try expectApproxEqRel(normalDist(-1), 0.1587, e2);
    try expectApproxEqRel(normalDist(0), 0.5, e2);
    try expectApproxEqRel(normalDist(1), 0.8413, e2);
    try expectApproxEqRel(normalDist(5), 1 - 2.867e-7, e2);
}

// sqrt(2pi)
const s2pi = math.sqrttau;

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
///    IEEE     0.125, 1        20000       7.2e-16     1.3e-16
///    IEEE     3e-308, 0.135   50000       4.6e-16     9.8e-17
///
///
/// ERROR MESSAGES:
///
///   message         condition    value returned
/// ndtri domain       x <= 0        -inf
/// ndtri domain       x >= 1         inf
pub fn inverseNormalDist(y0: f64) f64 {
    if (y0 <= 0.0) {
        return -math.inf(f64); // Domain error
    }

    if (y0 >= 1.0) {
        return math.inf(f64); // Domain error
    }

    var code = true;

    var y = y0;
    // 0.135... = exp(-2) // TODO: lift to constants
    if (y > 1.0 - 0.13533528323661269189) {
        y = 1.0 - y;
        code = false;
    }

    if (y > 0.13533528323661269189) {
        y = y - 0.5;
        const y2 = y * y;
        var x = y + y * (y2 * polevl(y2, P0[0..]) / p1evl(y2, Q0[0..]));
        x = x * s2pi;
        return x;
    }

    var x = math.sqrt(-2.0 * @log(y));
    const x0 = x - @log(x) / x;

    const z = 1.0 / x;

    // y > exp(-32) = 1.2664165549e-14
    const x1 = if (x < 8.0)
        z * polevl(z, P1[0..]) / p1evl(z, Q1[0..])
    else
        z * polevl(z, P2[0..]) / p1evl(z, Q2[0..]);

    x = if (code) x1 - x0 else x0 - x1;
    
    return x;
}

const expectApproxEqRel = std.testing.expectApproxEqRel;
const expect = std.testing.expect;
const epsilon = 1e5;

test "inverseNormalDist" {
    try expectApproxEqRel(inverseNormalDist(7.62e-24), -10, epsilon);
    try expectApproxEqRel(inverseNormalDist(0.1587), -1, epsilon);
    try expectApproxEqRel(inverseNormalDist(0.5), 0, epsilon);
    try expectApproxEqRel(inverseNormalDist(0.8413), 1, epsilon);
    try expectApproxEqRel(inverseNormalDist(1 - 2.867e-7), 5, epsilon);
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
    const x = if (a < 0.0) -a else a;
    if (x < 1.0) {
        return 1.0 - erf(a);
    }

    var z = -a * a;

    if (z < -C.MAXLOG) {
        return under(a);
    }

    if (USE_EXPXSQ) {
        // Compute z = exp(z).
        z = expx2(a, -1);
    } else {
        z = math.exp(z);
    }

    //var p: f64 = undefined;
    //var q: f64 = undefined;
    const p, const q = if (x < 8.0) .{ polevl(x, P[0..]), p1evl(x, Q[0..]) } else .{ polevl(x, R[0..]), p1evl(x, S[0..]) };

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
    // var p: f64 = undefined;
    // var q: f64 = undefined;
    const p, const q = if (x < 8.0) .{ polevl(x, P[0..]), p1evl(x, Q[0..]) } else .{ polevl(x, R[0..]), p1evl(x, S[0..]) };

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
///    IEEE      0,1         30000       3.7e-16     1.0e-16
pub fn erf(x: f64) f64 {
    if (@abs(x) > 1.0) {
        return 1.0 - erfc(x);
    }

    const z = x * x;
    const y = x * polevl(z, T[0..]) / p1evl(z, U[0..]);
    return y;
}

test "erf" {
    try expectApproxEqRel(erf(0), 0, epsilon);
    try expectApproxEqRel(erf(1), 0.8427007929497, epsilon);
    try expectApproxEqRel(erf(-1), -0.8427007929497, epsilon);
    try expectApproxEqRel(erf(5), 0.9999999999984625, epsilon);
}

test "erfc" {
    try expectApproxEqRel(erfc(0), 1, epsilon);
    try expectApproxEqRel(erfc(1), 0.157299207050285, epsilon);
    try expectApproxEqRel(erfc(-1), 1.84270079294971, epsilon);
    try expectApproxEqRel(erfc(5), 1.5374597944280e-12, epsilon);
}

test "erfce" {
    try expectApproxEqRel(erfce(0), 1, epsilon);
    try expectApproxEqRel(erfce(1), 0.4275835761558, epsilon);
    try expectApproxEqRel(erfce(-1), 5.008980080762283, 1e-3); // TODO: Confirm against c implementation
    try expectApproxEqRel(erfce(5), 0.1107046377339686, epsilon);
}

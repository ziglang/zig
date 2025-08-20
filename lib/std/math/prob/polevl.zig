// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.1:  December, 1988
// Copyright 1984, 1987, 1988 by Stephen L. Moshier
// Direct inquiries to 30 Frost Street, Cambridge, MA 02140

const std = @import("../../std.zig");

/// Evaluate polynomial
///
/// Evaluates polynomial of degree N:
///
///                     2          N
/// y  =  C  + C x + C x  +...+ C x
///        0    1     2          N
///
/// Coefficients are stored in reverse order:
///
/// coef[0] = C  , ..., coef[N] = C  .
///            N                   0
///
/// SPEED:
///
/// In the interest of speed, there are no checks for out
/// of bounds arithmetic.  This routine is used by most of
/// the functions in the library.  Depending on available
/// equipment features, the user may wish to rewrite the
/// program in microcode or assembly language.
pub fn polevl(x: f64, coef: []const f64) f64 {
    std.debug.assert(coef.len >= 1);

    var a = coef[0];
    for (coef[1..], 0..) |c, i| {
        a = a * x + c;
    }
    return a;
}

test "polevl" {
    const epsilon = 1e-6;
    const p = [_]f64{
        0.000160,
        0.001191,
        0.010421,
        0.047637,
        0.207448,
        0.494215,
        1.0,
    };

    std.testing.expectApproxEqRel(polevl(0.5, p[0..]), 1.305615, epsilon);
}

///							p1evl()
///                                          N
/// Evaluate polynomial when coefficient of x  is 1.0.
/// Otherwise same as polevl.
///
/// The function p1evl() assumes that coef[N] = 1.0 and is
/// omitted from the array.  Its calling arguments are
/// otherwise the same as polevl().
pub fn p1evl(x: f64, coef: []const f64) f64 {
    std.debug.assert(coef.len >= 1);

    var a = x + coef[0];
    for (coef[1..], 0..) |c, i| {
        a = a * x + c;
    }
    return a;
}

test "p1evl" {
    const epsilon = 1e-6;
    const p = [_]f64{
        -3.51815701436523470549e2,
        -1.70642106651881159223e4,
        -2.20528590553854454839e5,
        -1.13933444367982507207e6,
        -2.53252307177582951285e6,
        -2.01889141433532773231e6,
    };

    std.testing.expectApproxEqRel(p1evl(0.5, p[0..]), -3598630.126745, epsilon);
}

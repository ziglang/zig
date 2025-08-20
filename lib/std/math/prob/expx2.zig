// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Ported from the Cephes library. Original license below:
//
// Cephes Math Library Release 2.9:  June, 2000
// Copyright 2000 by Stephen L. Moshier

const std = @import("std");
const math = std.math;

const C = @import("constants.zig");

const M = 128.0;
const MINV = 0.0078125;

/// Exponential of squared argument
///
/// Computes y = exp(x*x) while suppressing error amplification
/// that would ordinarily arise from the inexactness of the
/// exponential argument x*x.
///
/// If sign < 0, the result is inverted; i.e., y = exp(-x*x) .
///
///
/// ACCURACY:
///
///                      Relative error:
/// arithmetic    domain     # trials      peak         rms
///   IEEE      -26.6, 26.6    10^7       3.9e-16     8.9e-17
pub fn expx2(x_: f64, sign: isize) f64 {
    var x = math.fabs(x_);

    if (sign < 0) {
        x = -x;
    }

    // Represent x as an exact multiple of M plus a residual.
    // M is a power of 2 chosen so that exp(m * m) does not overflow
    // or underflow and so that |x - m| is small.
    const m = MINV * math.floor(M * x + 0.5);
    const f = x - m;

    // x^2 = m^2 + 2mf + f^2
    var u = m * m;
    var u1_ = 2 * m * f + f * f;

    if (sign < 0) {
        u = -u;
        u1_ = -u1_;
    }

    if ((u + u1_) > C.MAXLOG) {
        return math.inf(f64);
    }

    // u is exact, u1_ is small.
    u = math.exp(u) * math.exp(u1_);
    return u;
}

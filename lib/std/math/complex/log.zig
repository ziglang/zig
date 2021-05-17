// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the natural logarithm of z.
pub fn log(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const r = cmath.abs(z);
    const phi = cmath.arg(z);

    return Complex(T).init(math.ln(r), phi);
}

const epsilon = 0.0001;

test "complex.clog" {
    const a = Complex(f32).init(5, 3);
    const c = log(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 1.763180, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 0.540419, epsilon));
}

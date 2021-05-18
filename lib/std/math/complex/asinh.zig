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

/// Returns the hyperbolic arc-sine of z.
pub fn asinh(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const q = Complex(T).init(-z.im, z.re);
    const r = cmath.asin(q);
    return Complex(T).init(r.im, -r.re);
}

const epsilon = 0.0001;

test "complex.casinh" {
    const a = Complex(f32).init(5, 3);
    const c = asinh(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 2.459831, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 0.533999, epsilon));
}

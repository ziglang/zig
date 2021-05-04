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

/// Returns the sine of z.
pub fn sin(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const p = Complex(T).new(-z.im, z.re);
    const q = cmath.sinh(p);
    return Complex(T).new(q.im, -q.re);
}

const epsilon = 0.0001;

test "complex.csin" {
    const a = Complex(f32).new(5, 3);
    const c = sin(a);

    try testing.expect(math.approxEqAbs(f32, c.re, -9.654126, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 2.841692, epsilon));
}

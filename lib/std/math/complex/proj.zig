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

/// Returns the projection of z onto the riemann sphere.
pub fn proj(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);

    if (math.isInf(z.re) or math.isInf(z.im)) {
        return Complex(T).new(math.inf(T), math.copysign(T, 0, z.re));
    }

    return Complex(T).new(z.re, z.im);
}

const epsilon = 0.0001;

test "complex.cproj" {
    const a = Complex(f32).new(5, 3);
    const c = proj(a);

    try testing.expect(c.re == 5 and c.im == 3);
}

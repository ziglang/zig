// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the arc-cosine of z.
pub fn acos(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const q = cmath.asin(z);
    return Complex(T).new(@as(T, math.pi) / 2 - q.re, -q.im);
}

const epsilon = 0.0001;

test "complex.cacos" {
    const a = Complex(f32).new(5, 3);
    const c = acos(a);

    testing.expect(math.approxEq(f32, c.re, 0.546975, epsilon));
    testing.expect(math.approxEq(f32, c.im, -2.452914, epsilon));
}

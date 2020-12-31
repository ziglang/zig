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

/// Returns the complex conjugate of z.
pub fn conj(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    return Complex(T).new(z.re, -z.im);
}

test "complex.conj" {
    const a = Complex(f32).new(5, 3);
    const c = a.conjugate();

    testing.expect(c.re == 5 and c.im == -3);
}

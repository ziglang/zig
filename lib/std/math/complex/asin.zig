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

// Returns the arc-sine of z.
pub fn asin(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const x = z.re;
    const y = z.im;

    const p = Complex(T).new(1.0 - (x - y) * (x + y), -2.0 * x * y);
    const q = Complex(T).new(-y, x);
    const r = cmath.log(q.add(cmath.sqrt(p)));

    return Complex(T).new(r.im, -r.re);
}

const epsilon = 0.0001;

test "complex.casin" {
    const a = Complex(f32).new(5, 3);
    const c = asin(a);

    testing.expect(math.approxEqAbs(f32, c.re, 1.023822, epsilon));
    testing.expect(math.approxEqAbs(f32, c.im, 2.452914, epsilon));
}

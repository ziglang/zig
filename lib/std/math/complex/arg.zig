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

/// Returns the angular component (in radians) of z.
pub fn arg(z: anytype) @TypeOf(z.re) {
    const T = @TypeOf(z.re);
    return math.atan2(T, z.im, z.re);
}

const epsilon = 0.0001;

test "complex.carg" {
    const a = Complex(f32).new(5, 3);
    const c = arg(a);
    testing.expect(math.approxEqAbs(f32, c, 0.540420, epsilon));
}

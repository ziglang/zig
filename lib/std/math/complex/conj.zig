const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Calculates the complex conjugate of complex number.
pub fn conj(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    return z.conjugate();
}

test conj {
    const a: Complex(f32) = .init(5, 3);
    const a_conj = conj(a);

    try testing.expectEqual(5, a_conj.re);
    try testing.expectEqual(-3, a_conj.im);
}

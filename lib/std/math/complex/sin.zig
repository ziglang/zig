const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const sinh = @import("sinh.zig").sinh;

/// Calculates the sine of complex number.
pub fn sin(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const sinhIZ = sinh(z.mulbyi());

    return .init(sinhIZ.im, -sinhIZ.re);
}

test sin {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const sin_a = sin(a);

    try testing.expectApproxEqAbs(-9.654126, sin_a.re, epsilon);
    try testing.expectApproxEqAbs(2.8416924, sin_a.im, epsilon);
}

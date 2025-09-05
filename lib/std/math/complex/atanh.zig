const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const atan = @import("atan.zig").atan;

/// Calculates the hyperbolic arc-tangent of complex number.
pub fn atanh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const atanIZ = atan(z.mulbyi());

    return .init(atanIZ.im, -atanIZ.re);
}

test atanh {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const atanh_a = atanh(a);

    try testing.expectApproxEqAbs(0.14694665, atanh_a.re, epsilon);
    try testing.expectApproxEqAbs(1.4808695, atanh_a.im, epsilon);
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const asin = @import("asin.zig").asin;

/// Calculates the hyperbolic arc-sine of complex number.
pub fn asinh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    return asin(z.mulByI()).mulByMinusI();
}

test asinh {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const asinh_a = asinh(a);

    try testing.expectApproxEqAbs(2.4598298, asinh_a.re, epsilon);
    try testing.expectApproxEqAbs(0.5339993, asinh_a.im, epsilon);
}

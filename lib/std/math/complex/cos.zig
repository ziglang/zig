const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const cosh = @import("cosh.zig").cosh;

/// Calculates the cosine of complex number.
pub fn cos(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    return cosh(z.mulByI());
}

test cos {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const cos_a = cos(a);

    try testing.expectApproxEqAbs(2.8558152, cos_a.re, epsilon);
    try testing.expectApproxEqAbs(9.606383, cos_a.im, epsilon);
}

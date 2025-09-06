const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const tanh = @import("tanh.zig").tanh;

/// Calculates the tangent of complex number.
pub fn tan(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    return tanh(z.mulByI()).mulByMinusI();
}

test tan {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const tan_a = tan(a);

    try testing.expectApproxEqAbs(-0.002708233, tan_a.re, epsilon);
    try testing.expectApproxEqAbs(1.0041647, tan_a.im, epsilon);
}

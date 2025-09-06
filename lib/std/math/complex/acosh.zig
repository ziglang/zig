const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const acos = @import("acos.zig").acos;

/// Calculates the hyperbolic arc-cosine of complex number.
pub fn acosh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const q = acos(z);

    return if (math.signbit(z.im))
        q.mulByMinusI()
    else
        q.mulByI();
}

test acosh {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const acosh_a = acosh(a);

    try testing.expectApproxEqAbs(2.4529128, acosh_a.re, epsilon);
    try testing.expectApproxEqAbs(0.5469737, acosh_a.im, epsilon);
}

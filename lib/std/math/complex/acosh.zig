const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const acos = @import("acos.zig").acos;

/// Returns the hyperbolic arc-cosine of z.
pub fn acosh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const q = acos(z);

    return if (math.signbit(z.im))
        .init(q.im, -q.re)
    else
        .init(-q.im, q.re);
}

test acosh {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = acosh(a);

    try testing.expectApproxEqAbs(2.4529128, b.re, epsilon);
    try testing.expectApproxEqAbs(0.5469737, b.im, epsilon);
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the hyperbolic arc-cosine of z.
pub fn acosh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = cmath.acos(z);

    return if (math.signbit(z.im))
        Complex(T).init(q.im, -q.re)
    else
        Complex(T).init(-q.im, q.re);
}

test acosh {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = acosh(a);

    try testing.expectApproxEqAbs(2.4529128, c.re, epsilon);
    try testing.expectApproxEqAbs(0.5469737, c.im, epsilon);
}

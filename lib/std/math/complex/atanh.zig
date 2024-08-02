const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the hyperbolic arc-tangent of z.
pub fn atanh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = Complex(T).init(-z.im, z.re);
    const r = cmath.atan(q);
    return Complex(T).init(r.im, -r.re);
}

test atanh {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = atanh(a);

    try testing.expectApproxEqAbs(0.14694665, c.re, epsilon);
    try testing.expectApproxEqAbs(1.4808695, c.im, epsilon);
}

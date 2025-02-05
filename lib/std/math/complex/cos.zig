const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the cosine of z.
pub fn cos(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const p = Complex(T).init(-z.im, z.re);
    return cmath.cosh(p);
}

test cos {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = cos(a);

    try testing.expectApproxEqAbs(2.8558152, c.re, epsilon);
    try testing.expectApproxEqAbs(9.606383, c.im, epsilon);
}

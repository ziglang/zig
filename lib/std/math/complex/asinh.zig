const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the hyperbolic arc-sine of z.
pub fn asinh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = Complex(T).init(-z.im, z.re);
    const r = cmath.asin(q);
    return Complex(T).init(r.im, -r.re);
}

test asinh {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = asinh(a);

    try testing.expectApproxEqAbs(2.4598298, c.re, epsilon);
    try testing.expectApproxEqAbs(0.5339993, c.im, epsilon);
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the tangent of z.
pub fn tan(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = Complex(T).init(-z.im, z.re);
    const r = cmath.tanh(q);
    return Complex(T).init(r.im, -r.re);
}

test tan {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = tan(a);

    try testing.expectApproxEqAbs(-0.002708233, c.re, epsilon);
    try testing.expectApproxEqAbs(1.0041647, c.im, epsilon);
}

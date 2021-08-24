const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the cosine of z.
pub fn cos(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const p = Complex(T).init(-z.im, z.re);
    return cmath.cosh(p);
}

const epsilon = 0.0001;

test "complex.ccos" {
    const a = Complex(f32).init(5, 3);
    const c = cos(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 2.855815, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 9.606383, epsilon));
}

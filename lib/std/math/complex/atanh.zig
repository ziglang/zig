const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the hyperbolic arc-tangent of z.
pub fn atanh(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const q = Complex(T).new(-z.im, z.re);
    const r = cmath.atan(q);
    return Complex(T).new(r.im, -r.re);
}

const epsilon = 0.0001;

test "complex.catanh" {
    const a = Complex(f32).new(5, 3);
    const c = atanh(a);

    testing.expect(math.approxEq(f32, c.re, 0.146947, epsilon));
    testing.expect(math.approxEq(f32, c.im, 1.480870, epsilon));
}

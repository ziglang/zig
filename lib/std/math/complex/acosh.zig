const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the hyperbolic arc-cosine of z.
pub fn acosh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = cmath.acos(z);
    return Complex(T).init(-q.im, q.re);
}

const epsilon = 0.0001;

test acosh {
    const a = Complex(f32).init(5, 3);
    const c = acosh(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 2.452914, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 0.546975, epsilon));
}

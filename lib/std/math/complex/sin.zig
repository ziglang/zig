const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the sine of z.
pub fn sin(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const p = Complex(T).init(-z.im, z.re);
    const q = cmath.sinh(p);
    return Complex(T).init(q.im, -q.re);
}

test sin {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = sin(a);

    try testing.expectApproxEqAbs(-9.654126, c.re, epsilon);
    try testing.expectApproxEqAbs(2.8416924, c.im, epsilon);
}

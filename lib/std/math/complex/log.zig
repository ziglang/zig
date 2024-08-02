const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the natural logarithm of z.
pub fn log(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const r = cmath.abs(z);
    const phi = cmath.arg(z);

    return Complex(T).init(@log(r), phi);
}

test log {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = log(a);

    try testing.expectApproxEqAbs(1.7631803, c.re, epsilon);
    try testing.expectApproxEqAbs(0.5404195, c.im, epsilon);
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns z raised to the complex power of c.
pub fn pow(comptime T: type, z: T, c: T) T {
    const p = cmath.log(z);
    const q = c.mul(p);
    return cmath.exp(q);
}

const epsilon = 0.0001;

test "complex.cpow" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2.3, -1.3);
    const c = pow(Complex(f32), a, b);

    try testing.expect(math.approxEqAbs(f32, c.re, 58.049110, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, -101.003433, epsilon));
}

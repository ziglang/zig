const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the absolute value (modulus) of z.
pub fn abs(z: anytype) @TypeOf(z.re) {
    const T = @TypeOf(z.re);
    return math.hypot(T, z.re, z.im);
}

const epsilon = 0.0001;

test "complex.cabs" {
    const a = Complex(f32).new(5, 3);
    const c = abs(a);
    testing.expect(math.approxEq(f32, c, 5.83095, epsilon));
}

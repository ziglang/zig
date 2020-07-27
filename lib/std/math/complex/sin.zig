const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the sine of z.
pub fn sin(z: anytype) Complex(@TypeOf(z.re)) {
    const T = @TypeOf(z.re);
    const p = Complex(T).new(-z.im, z.re);
    const q = cmath.sinh(p);
    return Complex(T).new(q.im, -q.re);
}

const epsilon = 0.0001;

test "complex.csin" {
    const a = Complex(f32).new(5, 3);
    const c = sin(a);

    testing.expect(math.approxEq(f32, c.re, -9.654126, epsilon));
    testing.expect(math.approxEq(f32, c.im, 2.841692, epsilon));
}

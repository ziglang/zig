const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the complex conjugate of z.
pub fn conj(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    return Complex(T).init(z.re, -z.im);
}

test conj {
    const a = Complex(f32).init(5, 3);
    const c = a.conjugate();

    try testing.expect(c.re == 5 and c.im == -3);
}

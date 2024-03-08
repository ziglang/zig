const std = @import("../../std.zig");
const complex = @import("../complex.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Returns z raised to the complex power of s.
pub fn pow(z: anytype, s: anytype) Complex(@TypeOf(z.re, z.im, s.re, s.im)) {
    return complex.exp(complex.log(z).mul(s));
}

const epsilon = 0.0001;

test pow {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2.3, -1.3);
    const c = pow(a, b);

    try testing.expect(math.approxEqAbs(f32, c.re, 58.049110, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, -101.003433, epsilon));
}

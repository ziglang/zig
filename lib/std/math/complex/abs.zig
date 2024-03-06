const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the absolute value (modulus) of z.
pub fn abs(z: anytype) @TypeOf(z.re, z.im) {
    return math.hypot(z.re, z.im);
}

const epsilon = 0.0001;

test abs {
    const a = Complex(f32).init(5, 3);
    const c = abs(a);
    try testing.expect(math.approxEqAbs(f32, c, 5.83095, epsilon));
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the absolute value (modulus) of z.
pub fn abs(z: anytype) @TypeOf(z.re, z.im) {
    return math.hypot(z.re, z.im);
}

test abs {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = abs(a);
    try testing.expectApproxEqAbs(5.8309517, c, epsilon);
}

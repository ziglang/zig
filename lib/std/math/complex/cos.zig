const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const cosh = @import("cosh.zig").cosh;

/// Returns the cosine of z.
pub fn cos(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const p = z.mulbyi();

    return cosh(p);
}

test cos {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = cos(a);

    try testing.expectApproxEqAbs(2.8558152, b.re, epsilon);
    try testing.expectApproxEqAbs(9.606383, b.im, epsilon);
}

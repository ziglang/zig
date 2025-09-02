const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const asin = @import("asin.zig").asin;

/// Returns the hyperbolic arc-sine of z.
pub fn asinh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const q = z.mulbyi();
    const r = asin(q);

    return .init(r.im, -r.re);
}

test asinh {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = asinh(a);

    try testing.expectApproxEqAbs(2.4598298, b.re, epsilon);
    try testing.expectApproxEqAbs(0.5339993, b.im, epsilon);
}

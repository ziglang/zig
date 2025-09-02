const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const atan = @import("atan.zig").atan;

/// Returns the hyperbolic arc-tangent of z.
pub fn atanh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const q = z.mulbyi();
    const r = atan(q);

    return .init(r.im, -r.re);
}

test atanh {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = atanh(a);

    try testing.expectApproxEqAbs(0.14694665, b.re, epsilon);
    try testing.expectApproxEqAbs(1.4808695, b.im, epsilon);
}

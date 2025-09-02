const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const tanh = @import("tanh.zig").tanh;

/// Returns the tangent of z.
pub fn tan(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const q = z.mulbyi();
    const r = tanh(q);

    return .init(r.im, -r.re);
}

test tan {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = tan(a);

    try testing.expectApproxEqAbs(-0.002708233, b.re, epsilon);
    try testing.expectApproxEqAbs(1.0041647, b.im, epsilon);
}

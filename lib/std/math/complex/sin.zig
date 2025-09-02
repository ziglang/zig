const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const sinh = @import("sinh.zig").sinh;

/// Returns the sine of z.
pub fn sin(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const p = z.mulbyi();
    const q = sinh(p);

    return .init(q.im, -q.re);
}

test sin {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = sin(a);

    try testing.expectApproxEqAbs(-9.654126, b.re, epsilon);
    try testing.expectApproxEqAbs(2.8416924, b.im, epsilon);
}

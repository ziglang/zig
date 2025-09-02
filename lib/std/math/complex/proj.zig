const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Returns the projection of z onto the riemann sphere.
pub fn proj(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    if (math.isInf(z.re) or math.isInf(z.im))
        return .init(
            math.inf(T),
            math.copysign(@as(T, 0.0), z.re),
        );

    return .init(z.re, z.im);
}

test proj {
    const a: Complex(f32) = .init(5, 3);
    const b = proj(a);

    try testing.expectEqual(5, b.re);
    try testing.expectEqual(3, b.im);
}

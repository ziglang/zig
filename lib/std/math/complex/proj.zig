const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Calculates the projection of a complex number onto the riemann sphere.
pub fn proj(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const x = z.re;
    const y = z.im;

    const T = @TypeOf(x, y);

    if (math.isInf(x) or math.isInf(y))
        return .init(
            math.inf(T),
            math.copysign(@as(T, 0), x),
        );

    return .init(x, y);
}

test proj {
    { // Finite complex number
        const a: Complex(f32) = .init(5, 3);
        const a_proj = proj(a);

        try testing.expectEqual(5, a_proj.re);
        try testing.expectEqual(3, a_proj.im);
    }

    { // Infinity complex number
        const inf = math.inf(f32);

        const a: Complex(f32) = .init(inf, 2);
        const a_proj = proj(a);

        try testing.expectEqual(inf, a_proj.re);
        try testing.expectEqual(0, a_proj.im);
    }
}

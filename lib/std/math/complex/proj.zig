const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the projection of z onto the riemann sphere.
pub fn proj(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    if (math.isInf(z.re) or math.isInf(z.im)) {
        return Complex(T).init(math.inf(T), math.copysign(@as(T, 0.0), z.re));
    }

    return Complex(T).init(z.re, z.im);
}

test proj {
    const a = Complex(f32).init(5, 3);
    const c = proj(a);

    try testing.expectEqual(5, c.re);
    try testing.expectEqual(3, c.im);
}

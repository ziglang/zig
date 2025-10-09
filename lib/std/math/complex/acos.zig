const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const asin = @import("asin.zig").asin;

/// Calculates the arc-cosine of a complex number.
pub fn acos(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    const q = asin(z);

    return .init(@as(T, math.pi) / 2 - q.re, -q.im);
}

test acos {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const acos_a = acos(a);

    try testing.expectApproxEqAbs(0.5469737, acos_a.re, epsilon);
    try testing.expectApproxEqAbs(-2.4529128, acos_a.im, epsilon);
}

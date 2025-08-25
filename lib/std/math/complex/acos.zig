const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the arc-cosine of z.
pub fn acos(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = cmath.asin(z);
    return Complex(T).init(@as(T, math.pi) / 2 - q.re, -q.im);
}

test acos {
    const epsilon = math.floatEps(f32);
    const a = Complex(f32).init(5, 3);
    const c = acos(a);

    try testing.expectApproxEqAbs(0.5469737, c.re, epsilon);
    try testing.expectApproxEqAbs(-2.4529128, c.im, epsilon);
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the sine of z.
pub fn sin(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = cmath.sinh(Complex(T).init(-z.im, z.re));
    return .{
        .re = q.im,
        .im = -q.re,
    };
}

const epsilon = 0.0001;

test sin {
    const a = Complex(f32).init(5, 3);
    const c = sin(a);

    try testing.expect(math.approxEqAbs(f32, c.re, -9.654126, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 2.841692, epsilon));
}

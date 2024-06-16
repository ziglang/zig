const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the tangent of z.
pub fn tan(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const r = cmath.tanh(Complex(T).init(-z.im, z.re));
    return .{
        .re = r.im,
        .im = -r.re,
    };
}

const epsilon = 0.0001;

test tan {
    const a = Complex(f32).init(5, 3);
    const c = tan(a);

    try testing.expect(math.approxEqAbs(f32, c.re, -0.002708233, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 1.004165, epsilon));
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the hyperbolic arc-sine of z.
pub fn asinh(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const r = cmath.asin(Complex(T).init(-z.im, z.re));
    return .{
        .re = r.im,
        .im = -r.re,
    };
}

const epsilon = 0.0001;

test asinh {
    const a = Complex(f32).init(5, 3);
    const c = asinh(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 2.459831, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 0.533999, epsilon));
}

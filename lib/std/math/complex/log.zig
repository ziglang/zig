const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the natural logarithm of z.
pub fn log(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    return .{
        .re = @log(math.hypot(z.re, z.im)),
        .im = math.atan2(z.im, z.re),
    };
}

const epsilon = 0.0001;

test log {
    const a = Complex(f32).init(5, 3);
    const c = log(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 1.763180, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 0.540419, epsilon));
}

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// Returns the angular component (in radians) of z.
pub fn arg(z: anytype) @TypeOf(z.re, z.im) {
    return math.atan2(z.im, z.re);
}

const epsilon = 0.0001;

test arg {
    const a = Complex(f32).init(5, 3);
    const c = arg(a);
    try testing.expect(math.approxEqAbs(f32, c, 0.540420, epsilon));
}

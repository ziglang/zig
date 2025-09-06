const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Calculates the angular component (in radians) of complex number.
pub fn arg(z: anytype) @TypeOf(z.re, z.im) {
    return math.atan2(z.im, z.re);
}

test arg {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const arg_a = arg(a);

    try testing.expectApproxEqAbs(0.5404195, arg_a, epsilon);
}

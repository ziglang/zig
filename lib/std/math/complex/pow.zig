const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const exp = @import("exp.zig").exp;
const log = @import("log.zig").log;

/// Returns z raised to the complex power of c.
pub fn pow(z: anytype, s: anytype) Complex(@TypeOf(z.re, z.im, s.re, s.im)) {
    return exp(log(z).mul(s));
}

test pow {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b: Complex(f32) = .init(2.3, -1.3);

    const c = pow(a, b);

    try testing.expectApproxEqAbs(58.049110, c.re, epsilon);
    try testing.expectApproxEqAbs(-101.003433, c.im, epsilon);
}

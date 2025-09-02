const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const abs = @import("abs.zig").abs;
const arg = @import("arg.zig").arg;

/// Returns the natural logarithm of z.
pub fn log(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const r = abs(z);
    const phi = arg(z);

    return .init(@log(r), phi);
}

test log {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = log(a);

    try testing.expectApproxEqAbs(1.7631803, b.re, epsilon);
    try testing.expectApproxEqAbs(0.5404195, b.im, epsilon);
}

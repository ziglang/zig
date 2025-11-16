const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const abs = @import("abs.zig").abs;
const arg = @import("arg.zig").arg;

/// Calculates the natural logarithm of a complex number.
pub fn log(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    return .init(@log(abs(z)), arg(z));
}

test log {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const log_a = log(a);

    try testing.expectApproxEqAbs(1.7631803, log_a.re, epsilon);
    try testing.expectApproxEqAbs(0.5404195, log_a.im, epsilon);
}

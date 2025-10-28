const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const sqrt = @import("sqrt.zig").sqrt;
const log = @import("log.zig").log;

/// Calculates the arc-sine of a complex number.
pub fn asin(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const x = z.re;
    const y = z.im;

    const T = @TypeOf(x, y);

    const p: Complex(T) = .init(
        1 - (x - y) * (x + y),
        -2 * x * y,
    );
    const q: Complex(T) = .init(-y, x);

    return log(q.add(sqrt(p))).mulByMinusI();
}

test asin {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const asin_a = asin(a);

    try testing.expectApproxEqAbs(1.0238227, asin_a.re, epsilon);
    try testing.expectApproxEqAbs(2.4529128, asin_a.im, epsilon);
}

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

const sqrt = @import("sqrt.zig").sqrt;
const log = @import("log.zig").log;

/// Calculates the arc-sine of complex number.
pub fn asin(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const x = z.re;
    const y = z.im;

    const T = @TypeOf(x);

    const p: Complex(T) = .init(
        1 - (x - y) * (x + y),
        -2 * x * y,
    );
    const q: Complex(T) = .init(-y, x);

    const r = log(q.add(sqrt(p)));

    return .init(r.im, -r.re);
}

test asin {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const b = asin(a);

    try testing.expectApproxEqAbs(1.0238227, b.re, epsilon);
    try testing.expectApproxEqAbs(2.4529128, b.im, epsilon);
}

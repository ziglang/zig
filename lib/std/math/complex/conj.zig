const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Returns the complex conjugate of z.
pub fn conj(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    return .init(z.re, -z.im);
}

test conj {
    const a: Complex(f32) = .init(5, 3);
    const b = a.conjugate();

    try testing.expectEqual(5, b.re);
    try testing.expectEqual(-3, b.im);
}

const std = @import("../../std.zig");
const complex = @import("../complex.zig");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Returns the arc-cosine of z.
pub fn acos(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const q = complex.asin(z);
    return Complex(T).init(@as(T, math.pi) / 2 - q.re, -q.im);
}

const epsilon = 0.0001;

test acos {
    const a = Complex(f32).init(5, 3);
    const c = acos(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 0.546975, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, -2.452914, epsilon));
}

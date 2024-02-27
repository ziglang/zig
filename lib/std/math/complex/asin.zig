const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

// Returns the arc-sine of z.
pub fn asin(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    const x = z.re;
    const y = z.im;

    const p = Complex(T).init(1.0 - (x - y) * (x + y), -2.0 * x * y);
    const q = Complex(T).init(-y, x);
    const r = cmath.log(q.add(cmath.sqrt(p)));

    return Complex(T).init(r.im, -r.re);
}

const epsilon = 0.0001;

test asin {
    const a = Complex(f32).init(5, 3);
    const c = asin(a);

    try testing.expect(math.approxEqAbs(f32, c.re, 1.023822, epsilon));
    try testing.expect(math.approxEqAbs(f32, c.im, 2.452914, epsilon));
}

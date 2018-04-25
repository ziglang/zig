const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn atanh(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);
    const q = Complex(T).new(-z.im, z.re);
    const r = cmath.atan(q);
    return Complex(T).new(r.im, -r.re);
}

const epsilon = 0.0001;

test "complex.catanh" {
    const a = Complex(f32).new(5, 3);
    const c = atanh(a);

    debug.assert(math.approxEq(f32, c.re, 0.146947, epsilon));
    debug.assert(math.approxEq(f32, c.im, 1.480870, epsilon));
}

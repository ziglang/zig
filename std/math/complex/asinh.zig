const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn asinh(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);
    const q = Complex(T).new(-z.im, z.re);
    const r = cmath.asin(q);
    return Complex(T).new(r.im, -r.re);
}

const epsilon = 0.0001;

test "complex.casinh" {
    const a = Complex(f32).new(5, 3);
    const c = asinh(a);

    debug.assert(math.approxEq(f32, c.re, 2.459831, epsilon));
    debug.assert(math.approxEq(f32, c.im, 0.533999, epsilon));
}

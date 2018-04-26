const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn cos(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);
    const p = Complex(T).new(-z.im, z.re);
    return cmath.cosh(p);
}

const epsilon = 0.0001;

test "complex.ccos" {
    const a = Complex(f32).new(5, 3);
    const c = cos(a);

    debug.assert(math.approxEq(f32, c.re, 2.855815, epsilon));
    debug.assert(math.approxEq(f32, c.im, 9.606383, epsilon));
}

const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn conj(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);
    return Complex(T).new(z.re, -z.im);
}

test "complex.conj" {
    const a = Complex(f32).new(5, 3);
    const c = a.conjugate();

    debug.assert(c.re == 5 and c.im == -3);
}

const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn acos(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);
    const q = cmath.asin(z);
    return Complex(T).new(T(math.pi) / 2 - q.re, -q.im);
}

const epsilon = 0.0001;

test "complex.cacos" {
    const a = Complex(f32).new(5, 3);
    const c = acos(a);

    const re = c.re;
    const im = c.im;

    debug.assert(math.approxEq(f32, re, 0.546975, epsilon));
    debug.assert(math.approxEq(f32, im, -2.452914, epsilon));
}

const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn acosh(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);
    const q = cmath.acos(z);
    return Complex(T).new(-q.im, q.re);
}

const epsilon = 0.0001;

test "complex.cacosh" {
    const a = Complex(f32).new(5, 3);
    const c = acosh(a);

    debug.assert(math.approxEq(f32, c.re, 2.452914, epsilon));
    debug.assert(math.approxEq(f32, c.im, 0.546975, epsilon));
}

const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn proj(z: var) Complex(@typeOf(z.re)) {
    const T = @typeOf(z.re);

    if (math.isInf(z.re) or math.isInf(z.im)) {
        return Complex(T).new(math.inf(T), math.copysign(T, 0, z.re));
    }

    return Complex(T).new(z.re, z.im);
}

const epsilon = 0.0001;

test "complex.cproj" {
    const a = Complex(f32).new(5, 3);
    const c = proj(a);

    debug.assert(c.re == 5 and c.im == 3);
}

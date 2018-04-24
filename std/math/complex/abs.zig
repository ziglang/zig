const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn abs(z: var) @typeOf(z.re) {
    const T = @typeOf(z.re);
    return math.hypot(T, z.re, z.im);
}

const epsilon = 0.0001;

test "complex.cabs" {
    const a = Complex(f32).new(5, 3);
    const c = abs(a);
    debug.assert(math.approxEq(f32, c, 5.83095, epsilon));
}

const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn pow(comptime T: type, z: *const T, c: *const T) T {
    const p = cmath.log(z);
    const q = c.mul(p);
    return cmath.exp(q);
}

const epsilon = 0.0001;

test "complex.cpow" {
    const a = Complex(f32).new(5, 3);
    const b = Complex(f32).new(2.3, -1.3);
    const c = pow(Complex(f32), a, b);

    debug.assert(math.approxEq(f32, c.re, 58.049110, epsilon));
    debug.assert(math.approxEq(f32, c.im, -101.003433, epsilon));
}

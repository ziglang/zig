const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

pub fn arg(z: var) @typeOf(z.re) {
    const T = @typeOf(z.re);
    return math.atan2(T, z.im, z.re);
}

const epsilon = 0.0001;

test "complex.carg" {
    const a = Complex(f32).new(5, 3);
    const c = arg(a);
    debug.assert(math.approxEq(f32, c, 0.540420, epsilon));
}

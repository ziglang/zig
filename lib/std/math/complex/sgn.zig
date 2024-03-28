const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;
const cmath = math.complex;
const Complex = cmath.Complex;

/// The signum function returns the polarity (unit phasor) of a complex number.
/// sgn(z) == exp(i*arg(z))
pub fn sgn(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);
    if (z.re != z.re or z.im != z.im) return Complex(T).init(z.re + z.im, z.re + z.im);
    if (z.im == 0) return Complex(T).init(math.sign(z.re), 0);
    if (z.re == 0) return Complex(T).init(0, math.sign(z.im));
    const arg = math.atan2(z.im, z.re);
    return Complex(T).init(@cos(arg), @sin(arg));
}

const epsilon = 0.0001;

test "complex.csgn" {
    const one: f32 = 1;
    const zero: f32 = 0;
    const nan: f32 = zero / zero;
    const pinf: f32 = one / zero;
    const ninf: f32 = -one / zero;
    const nzero: f32 = one / ninf;
    const diag: f32 = @sqrt(0.5);

    const pinf_pinf = sgn(Complex(f32).init(pinf, pinf));
    try testing.expect(math.approxEqAbs(f32, pinf_pinf.re, diag, epsilon));
    try testing.expect(math.approxEqAbs(f32, pinf_pinf.im, diag, epsilon));

    const pinf_zero = sgn(Complex(f32).init(pinf, zero));
    try testing.expect(pinf_zero.re == 1);
    try testing.expect(pinf_zero.im == 0);

    const zero_pinf = sgn(Complex(f32).init(zero, pinf));
    try testing.expect(zero_pinf.re == 0);
    try testing.expect(zero_pinf.im == 1);

    const nzero_zero = sgn(Complex(f32).init(nzero, zero));
    try testing.expect(nzero_zero.re == 0);
    try testing.expect(nzero_zero.im == 0);

    const nan_one = sgn(Complex(f32).init(nan, one));
    try testing.expect(nan_one.re != nan_one.re);
    try testing.expect(nan_one.im != nan_one.im);

    const one_nan = sgn(Complex(f32).init(one, nan));
    try testing.expect(one_nan.re != one_nan.re);
    try testing.expect(one_nan.im != one_nan.im);
}

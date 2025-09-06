const std = @import("../std.zig");
const testing = std.testing;
const math = std.math;

pub const abs = @import("complex/abs.zig").abs;
pub const acosh = @import("complex/acosh.zig").acosh;
pub const acos = @import("complex/acos.zig").acos;
pub const arg = @import("complex/arg.zig").arg;
pub const asinh = @import("complex/asinh.zig").asinh;
pub const asin = @import("complex/asin.zig").asin;
pub const atanh = @import("complex/atanh.zig").atanh;
pub const atan = @import("complex/atan.zig").atan;
pub const cosh = @import("complex/cosh.zig").cosh;
pub const cos = @import("complex/cos.zig").cos;
pub const exp = @import("complex/exp.zig").exp;
pub const log = @import("complex/log.zig").log;
pub const pow = @import("complex/pow.zig").pow;
pub const proj = @import("complex/proj.zig").proj;
pub const sinh = @import("complex/sinh.zig").sinh;
pub const sin = @import("complex/sin.zig").sin;
pub const sqrt = @import("complex/sqrt.zig").sqrt;
pub const tanh = @import("complex/tanh.zig").tanh;
pub const tan = @import("complex/tan.zig").tan;

/// A complex number consisting of a real an imaginary part.
/// T must be a floating-point value.
pub fn Complex(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Real part.
        re: T,

        /// Imaginary part.
        im: T,

        /// Imarinary unit that satisfies "i^2 = -1".
        pub const i: Self = .init(0, 1);

        /// Create a new complex number from the given real and imaginary parts.
        pub fn init(re: T, im: T) Self {
            return .{
                .re = re,
                .im = im,
            };
        }

        /// Returns the sum of two complex numbers.
        pub fn add(self: Self, other: Self) Self {
            return .{
                .re = self.re + other.re,
                .im = self.im + other.im,
            };
        }

        /// Returns the subtraction of two complex numbers.
        pub fn sub(self: Self, other: Self) Self {
            return .{
                .re = self.re - other.re,
                .im = self.im - other.im,
            };
        }

        /// Returns the product of two complex numbers.
        pub fn mul(self: Self, other: Self) Self {
            return .{
                .re = self.re * other.re - self.im * other.im,
                .im = self.im * other.re + self.re * other.im,
            };
        }

        /// Returns the quotient of two complex numbers.
        pub fn div(self: Self, other: Self) Self {
            const re_num = self.re * other.re + self.im * other.im;
            const im_num = self.im * other.re - self.re * other.im;
            const den = other.re * other.re + other.im * other.im;

            return .{
                .re = re_num / den,
                .im = im_num / den,
            };
        }

        /// Returns the complex conjugate of a complex number.
        pub fn conj(self: Self) Self {
            return .{
                .re = self.re,
                .im = -self.im,
            };
        }

        /// Returns the negation of a complex number.
        pub fn neg(self: Self) Self {
            return .{
                .re = -self.re,
                .im = -self.im,
            };
        }

        /// Returns the product of complex number and imaginary unit.
        /// You should not manually does ".mul(.i, *)" instead of using this,
        /// as its consumes more operations than this.
        pub fn mulByI(self: Self) Self {
            return .{
                .re = -self.im,
                .im = self.re,
            };
        }

        /// Returns the product of complex number and negation of imaginary unit,
        /// thus this rotates 90 degrees clockwise on the complex plane.
        /// You should not manually does "*.neg().mul(.i)" instead of using this,
        /// as its consumes more operations than this.
        pub fn mulByMinusI(self: Self) Self {
            return .{
                .re = self.im,
                .im = -self.re,
            };
        }

        /// Returns the reciprocal of a complex number.
        pub fn recip(self: Self) Self {
            const magnitude_sq = self.squaredMagnitude();

            return .{
                .re = self.re / magnitude_sq,
                .im = -self.im / magnitude_sq,
            };
        }

        /// Returns the squared magnitude.
        pub fn squaredMagnitude(self: Self) T {
            return self.re * self.re + self.im * self.im;
        }

        /// Returns the magnitude of a complex number.
        pub fn magnitude(self: Self) T {
            return @sqrt(self.squaredMagnitude());
        }
    };
}

const TestingComplex = Complex(f32);

const testing_epsilon = 0.0001;

test "add" {
    const a: TestingComplex = .init(5, 3);
    const b: TestingComplex = .init(2, 7);

    const a_add_b = a.add(b);

    try testing.expectEqual(7, a_add_b.re);
    try testing.expectEqual(10, a_add_b.im);
}

test "sub" {
    const a: TestingComplex = .init(5, 3);
    const b: TestingComplex = .init(2, 7);

    const a_sub_b = a.sub(b);

    try testing.expectEqual(3, a_sub_b.re);
    try testing.expectEqual(-4, a_sub_b.im);
}

test "mul" {
    const a: TestingComplex = .init(5, 3);
    const b: TestingComplex = .init(2, 7);

    const a_mul_b = a.mul(b);

    try testing.expectEqual(-11, a_mul_b.re);
    try testing.expectEqual(41, a_mul_b.im);
}

test "div" {
    const a: TestingComplex = .init(5, 3);
    const b: TestingComplex = .init(2, 7);

    const a_div_b = a.div(b);

    try testing.expectApproxEqAbs(@as(f32, 31) / 53, a_div_b.re, testing_epsilon);
    try testing.expectApproxEqAbs(@as(f32, -29) / 53, a_div_b.im, testing_epsilon);
}

test "conj" {
    const a: TestingComplex = .init(5, 3);
    const a_conj = a.conj();

    try testing.expectEqual(5, a_conj.re);
    try testing.expectEqual(-3, a_conj.im);
}

test "neg" {
    const a: TestingComplex = .init(5, 3);
    const neg_a = a.neg();

    try testing.expectEqual(-5, neg_a.re);
    try testing.expectEqual(-3, neg_a.im);
}

test "mulByI" {
    const a: TestingComplex = .init(5, 3);
    const i_a = a.mulByI();

    try testing.expectEqual(-3, i_a.re);
    try testing.expectEqual(5, i_a.im);
}

test "multiplication by i yields same result as mulByI" {
    const a: TestingComplex = .init(5, 3);

    const i_a_natural = a.mulByI();
    const i_a_intentional: TestingComplex = .mul(.i, a);

    try testing.expectEqual(i_a_intentional.re, i_a_natural.re);
    try testing.expectEqual(i_a_intentional.im, i_a_natural.im);
}

test "mulByMinusI" {
    const a: TestingComplex = .init(5, 3);
    const minus_i_a = a.mulByMinusI();

    try testing.expectEqual(3, minus_i_a.re);
    try testing.expectEqual(-5, minus_i_a.im);
}

test "multiplication by negation of i yields same result as mulByMinusI" {
    const a: TestingComplex = .init(5, 3);

    const minus_i_a_natural = a.mulByMinusI();
    const minus_i_a_intentional: TestingComplex = a.neg().mul(.i); // x.neg().mul(.i) -> -ix

    try testing.expectEqual(minus_i_a_intentional.re, minus_i_a_natural.re);
    try testing.expectEqual(minus_i_a_intentional.im, minus_i_a_natural.im);
}

test "i^2 equals to -1" {
    const a: TestingComplex = .mul(.i, .i);

    try testing.expectEqual(-1, a.re);
    try testing.expectEqual(0, a.im);
}

test "(-i)^2 equals to -1" {
    const a: TestingComplex = .mul(.neg(.i), .neg(.i));

    try testing.expectEqual(-1, a.re);
    try testing.expectEqual(0, a.im);
}

test "recip" {
    const a: TestingComplex = .init(5, 3);
    const a_recip = a.recip();

    try testing.expectApproxEqAbs(@as(f32, 5) / 34, a_recip.re, testing_epsilon);
    try testing.expectApproxEqAbs(@as(f32, -3) / 34, a_recip.im, testing_epsilon);
}

test "magnitude" {
    const a: TestingComplex = .init(5, 3);
    const a_magnitude = a.magnitude();

    try testing.expectApproxEqAbs(5.83095, a_magnitude, testing_epsilon);
}

test "squaredMagnitude" {
    const a: TestingComplex = .init(5, 3);
    const a_magnitude_sq = a.squaredMagnitude();

    try testing.expectApproxEqAbs(math.pow(f32, a.magnitude(), 2), a_magnitude_sq, testing_epsilon);
}

test {
    _ = @import("complex/abs.zig");
    _ = @import("complex/acosh.zig");
    _ = @import("complex/acos.zig");
    _ = @import("complex/arg.zig");
    _ = @import("complex/asinh.zig");
    _ = @import("complex/asin.zig");
    _ = @import("complex/atanh.zig");
    _ = @import("complex/atan.zig");
    _ = @import("complex/cosh.zig");
    _ = @import("complex/cos.zig");
    _ = @import("complex/exp.zig");
    _ = @import("complex/log.zig");
    _ = @import("complex/pow.zig");
    _ = @import("complex/proj.zig");
    _ = @import("complex/sinh.zig");
    _ = @import("complex/sin.zig");
    _ = @import("complex/sqrt.zig");
    _ = @import("complex/tanh.zig");
    _ = @import("complex/tan.zig");
}

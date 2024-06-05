const std = @import("../std.zig");
const testing = std.testing;
const math = std.math;
const complex = @This();

pub const abs = @import("complex/abs.zig").abs;
pub const acosh = @import("complex/acosh.zig").acosh;
pub const acos = @import("complex/acos.zig").acos;
pub const arg = @import("complex/arg.zig").arg;
pub const asinh = @import("complex/asinh.zig").asinh;
pub const asin = @import("complex/asin.zig").asin;
pub const atanh = @import("complex/atanh.zig").atanh;
pub const atan = @import("complex/atan.zig").atan;
pub const conj = @import("complex/conj.zig").conj;
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

/// A complex number consisting of a real an imaginary part. T must be a floating-point value.
pub fn Complex(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Real part.
        re: T,

        /// Imaginary part.
        im: T,

        /// Create a new Complex number from the given real and imaginary parts.
        pub fn init(re: T, im: T) Self {
            return Self{
                .re = re,
                .im = im,
            };
        }

        /// Returns the sum of two complex numbers.
        pub fn add(self: Self, other: anytype) Self {
            return if (isComplex(@TypeOf(other))) .{
                .re = self.re + other.re,
                .im = self.im + other.im,
            } else .{
                .re = self.re + other,
                .im = self.im,
            };
        }

        /// Returns the difference of two complex numbers.
        pub fn sub(self: Self, other: anytype) Self {
            return if (isComplex(@TypeOf(other))) .{
                .re = self.re - other.re,
                .im = self.im - other.im,
            } else .{
                .re = self.re - other,
                .im = self.im,
            };
        }

        /// Returns the product of two complex numbers.
        pub fn mul(self: Self, other: anytype) Self {
            return if (isComplex(@TypeOf(other))) .{
                .re = self.re * other.re - self.im * other.im,
                .im = self.im * other.re + self.re * other.im,
            } else .{
                .re = self.re * other,
                .im = self.im * other,
            };
        }

        /// Returns the quotient of two complex numbers.
        pub fn div(self: Self, other: anytype) Self {
            const abs2 = if (isComplex(@TypeOf(other))) other.re * other.re + other.im * other.im else other;
            return if (isComplex(@TypeOf(other))) .{
                .re = (self.re * other.re + self.im * other.im) / abs2,
                .im = (self.im * other.re - self.re * other.im) / abs2,
            } else .{
                .re = self.re / other,
                .im = self.im / other,
            };
        }

        /// Returns the conjugate of a complex number.
        pub fn conj(self: Self) Self {
            return Self{
                .re = self.re,
                .im = -self.im,
            };
        }

        /// Returns the negation of a complex number.
        pub fn neg(self: Self) Self {
            return Self{
                .re = -self.re,
                .im = -self.im,
            };
        }

        /// Returns the product of complex number and i=sqrt(-1)
        pub fn mulbyi(self: Self) Self {
            return Self{
                .re = -self.im,
                .im = self.re,
            };
        }

        /// Returns the inverse of a complex number.
        pub fn inv(self: Self) Self {
            return self.conj().div(self.re * self.re + self.im * self.im);
        }

        /// Returns the magnitude of a complex number.
        pub fn abs(self: Self) T {
            return complex.abs(self);
        }
    };
}

/// Returns the underlying scalar type if it is a complex number,
/// otherwise return the type (and hopefully trigger a compile error if it's unsupported);
pub inline fn ScalarType(comptime T: type) type {
    if (!isComplex(T)) return T;
    const t: T = undefined;
    return @TypeOf(t.re, t.im);
}

/// Checks whether the input value is a struct which has fields named "re" and "im" and decl "ScalarType"
pub inline fn isComplex(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Struct => @hasField(T, "re") and @hasField(T, "im"),
        else => false,
    };
}

test isComplex {
    const C = Complex(f32);
    try testing.expect(isComplex(C));
}

const epsilon = 0.0001;

test "add" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.add(b);
    const d = c.add(1);
    try testing.expect(c.re == 7 and c.im == 10);
    try testing.expect(d.re == 8 and d.im == 10);
}

test "sub" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.sub(b);
    const d = c.sub(1);
    try testing.expect(c.re == 3 and c.im == -4);
    try testing.expect(d.re == 2 and d.im == -4);
}

test "mul" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.mul(b);
    const d = c.mul(2);
    try testing.expect(c.re == -11 and c.im == 41);
    try testing.expect(d.re == -22 and d.im == 82);
}

test "div" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.div(b);
    const d = c.div(2);
    try testing.expect(math.approxEqAbs(f32, c.re, @as(f32, 31) / 53, epsilon) and
        math.approxEqAbs(f32, c.im, @as(f32, -29) / 53, epsilon));
    try testing.expect(math.approxEqAbs(f32, d.re, @as(f32, 31) / 106, epsilon) and
        math.approxEqAbs(f32, d.im, @as(f32, -29) / 106, epsilon));
}

test "conj" {
    const a = Complex(f32).init(5, 3);
    const c = a.conj();

    try testing.expect(c.re == 5 and c.im == -3);
}

test "neg" {
    const a = Complex(f32).init(5, 3);
    const c = a.neg();

    try testing.expect(c.re == -5 and c.im == -3);
}

test "mulbyi" {
    const a = Complex(f32).init(5, 3);
    const c = a.mulbyi();

    try testing.expect(c.re == -3 and c.im == 5);
}

test "inv" {
    const a = Complex(f32).init(5, 3);
    const c = a.inv();

    try testing.expect(math.approxEqAbs(f32, c.re, @as(f32, 5) / 34, epsilon) and
        math.approxEqAbs(f32, c.im, @as(f32, -3) / 34, epsilon));
}

test "abs" {
    const a = Complex(f32).init(5, 3);
    const c = a.abs();

    try testing.expect(math.approxEqAbs(f32, c, 5.83095, epsilon));
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
    _ = @import("complex/conj.zig");
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

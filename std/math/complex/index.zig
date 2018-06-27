const std = @import("../../index.zig");
const debug = std.debug;
const math = std.math;

pub const abs = @import("abs.zig").abs;
pub const acosh = @import("acosh.zig").acosh;
pub const acos = @import("acos.zig").acos;
pub const arg = @import("arg.zig").arg;
pub const asinh = @import("asinh.zig").asinh;
pub const asin = @import("asin.zig").asin;
pub const atanh = @import("atanh.zig").atanh;
pub const atan = @import("atan.zig").atan;
pub const conj = @import("conj.zig").conj;
pub const cosh = @import("cosh.zig").cosh;
pub const cos = @import("cos.zig").cos;
pub const exp = @import("exp.zig").exp;
pub const log = @import("log.zig").log;
pub const pow = @import("pow.zig").pow;
pub const proj = @import("proj.zig").proj;
pub const sinh = @import("sinh.zig").sinh;
pub const sin = @import("sin.zig").sin;
pub const sqrt = @import("sqrt.zig").sqrt;
pub const tanh = @import("tanh.zig").tanh;
pub const tan = @import("tan.zig").tan;

pub fn Complex(comptime T: type) type {
    return struct {
        const Self = this;

        re: T,
        im: T,

        pub fn new(re: T, im: T) Self {
            return Self{
                .re = re,
                .im = im,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return Self{
                .re = self.re + other.re,
                .im = self.im + other.im,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self{
                .re = self.re - other.re,
                .im = self.im - other.im,
            };
        }

        pub fn mul(self: Self, other: Self) Self {
            return Self{
                .re = self.re * other.re - self.im * other.im,
                .im = self.im * other.re + self.re * other.im,
            };
        }

        pub fn div(self: Self, other: Self) Self {
            const re_num = self.re * other.re + self.im * other.im;
            const im_num = self.im * other.re - self.re * other.im;
            const den = other.re * other.re + other.im * other.im;

            return Self{
                .re = re_num / den,
                .im = im_num / den,
            };
        }

        pub fn conjugate(self: Self) Self {
            return Self{
                .re = self.re,
                .im = -self.im,
            };
        }

        pub fn reciprocal(self: Self) Self {
            const m = self.re * self.re + self.im * self.im;
            return Self{
                .re = self.re / m,
                .im = -self.im / m,
            };
        }

        pub fn magnitude(self: Self) T {
            return math.sqrt(self.re * self.re + self.im * self.im);
        }
    };
}

const epsilon = 0.0001;

test "complex.add" {
    const a = Complex(f32).new(5, 3);
    const b = Complex(f32).new(2, 7);
    const c = a.add(b);

    debug.assert(c.re == 7 and c.im == 10);
}

test "complex.sub" {
    const a = Complex(f32).new(5, 3);
    const b = Complex(f32).new(2, 7);
    const c = a.sub(b);

    debug.assert(c.re == 3 and c.im == -4);
}

test "complex.mul" {
    const a = Complex(f32).new(5, 3);
    const b = Complex(f32).new(2, 7);
    const c = a.mul(b);

    debug.assert(c.re == -11 and c.im == 41);
}

test "complex.div" {
    const a = Complex(f32).new(5, 3);
    const b = Complex(f32).new(2, 7);
    const c = a.div(b);

    debug.assert(math.approxEq(f32, c.re, f32(31) / 53, epsilon) and
        math.approxEq(f32, c.im, f32(-29) / 53, epsilon));
}

test "complex.conjugate" {
    const a = Complex(f32).new(5, 3);
    const c = a.conjugate();

    debug.assert(c.re == 5 and c.im == -3);
}

test "complex.reciprocal" {
    const a = Complex(f32).new(5, 3);
    const c = a.reciprocal();

    debug.assert(math.approxEq(f32, c.re, f32(5) / 34, epsilon) and
        math.approxEq(f32, c.im, f32(-3) / 34, epsilon));
}

test "complex.magnitude" {
    const a = Complex(f32).new(5, 3);
    const c = a.magnitude();

    debug.assert(math.approxEq(f32, c, 5.83095, epsilon));
}

test "complex.cmath" {
    _ = @import("abs.zig");
    _ = @import("acosh.zig");
    _ = @import("acos.zig");
    _ = @import("arg.zig");
    _ = @import("asinh.zig");
    _ = @import("asin.zig");
    _ = @import("atanh.zig");
    _ = @import("atan.zig");
    _ = @import("conj.zig");
    _ = @import("cosh.zig");
    _ = @import("cos.zig");
    _ = @import("exp.zig");
    _ = @import("log.zig");
    _ = @import("pow.zig");
    _ = @import("proj.zig");
    _ = @import("sinh.zig");
    _ = @import("sin.zig");
    _ = @import("sqrt.zig");
    _ = @import("tanh.zig");
    _ = @import("tan.zig");
}

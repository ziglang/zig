// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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

        /// Deprecated, use init()
        pub const new = init;

        /// Create a new Complex number from the given real and imaginary parts.
        pub fn init(re: T, im: T) Self {
            return Self{
                .re = re,
                .im = im,
            };
        }

        /// Returns the sum of two complex numbers.
        pub fn add(self: Self, other: Self) Self {
            return Self{
                .re = self.re + other.re,
                .im = self.im + other.im,
            };
        }

        /// Returns the subtraction of two complex numbers.
        pub fn sub(self: Self, other: Self) Self {
            return Self{
                .re = self.re - other.re,
                .im = self.im - other.im,
            };
        }

        /// Returns the product of two complex numbers.
        pub fn mul(self: Self, other: Self) Self {
            return Self{
                .re = self.re * other.re - self.im * other.im,
                .im = self.im * other.re + self.re * other.im,
            };
        }

        /// Returns the quotient of two complex numbers.
        pub fn div(self: Self, other: Self) Self {
            const re_num = self.re * other.re + self.im * other.im;
            const im_num = self.im * other.re - self.re * other.im;
            const den = other.re * other.re + other.im * other.im;

            return Self{
                .re = re_num / den,
                .im = im_num / den,
            };
        }

        /// Returns the complex conjugate of a number.
        pub fn conjugate(self: Self) Self {
            return Self{
                .re = self.re,
                .im = -self.im,
            };
        }

        /// Returns the reciprocal of a complex number.
        pub fn reciprocal(self: Self) Self {
            const m = self.re * self.re + self.im * self.im;
            return Self{
                .re = self.re / m,
                .im = -self.im / m,
            };
        }

        /// Returns the magnitude of a complex number.
        pub fn magnitude(self: Self) T {
            return math.sqrt(self.re * self.re + self.im * self.im);
        }
    };
}

const epsilon = 0.0001;

test "complex.add" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.add(b);

    try testing.expect(c.re == 7 and c.im == 10);
}

test "complex.sub" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.sub(b);

    try testing.expect(c.re == 3 and c.im == -4);
}

test "complex.mul" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.mul(b);

    try testing.expect(c.re == -11 and c.im == 41);
}

test "complex.div" {
    const a = Complex(f32).init(5, 3);
    const b = Complex(f32).init(2, 7);
    const c = a.div(b);

    try testing.expect(math.approxEqAbs(f32, c.re, @as(f32, 31) / 53, epsilon) and
        math.approxEqAbs(f32, c.im, @as(f32, -29) / 53, epsilon));
}

test "complex.conjugate" {
    const a = Complex(f32).init(5, 3);
    const c = a.conjugate();

    try testing.expect(c.re == 5 and c.im == -3);
}

test "complex.reciprocal" {
    const a = Complex(f32).init(5, 3);
    const c = a.reciprocal();

    try testing.expect(math.approxEqAbs(f32, c.re, @as(f32, 5) / 34, epsilon) and
        math.approxEqAbs(f32, c.im, @as(f32, -3) / 34, epsilon));
}

test "complex.magnitude" {
    const a = Complex(f32).init(5, 3);
    const c = a.magnitude();

    try testing.expect(math.approxEqAbs(f32, c, 5.83095, epsilon));
}

test "complex.cmath" {
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

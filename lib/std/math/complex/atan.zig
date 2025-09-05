//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/catanf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/catan.c

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

/// Calculates the arc-tangent of complex number.
pub fn atan(z: anytype) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    return switch (T) {
        f32 => atan32(z),
        f64 => atan64(z),
        else => @compileError("atan not implemented for " ++ @typeName(T)),
    };
}

fn redupif32(x: f32) f32 {
    const dp1 = 3.140625;
    const dp2 = 9.67502593994140625e-4;
    const dp3 = 1.509957990978376432e-7;

    var t = x / math.pi;

    if (t >= 0.0)
        t += 0.5
    else
        t -= 0.5;

    const u: f32 = @trunc(t);

    return ((x - u * dp1) - u * dp2) - u * dp3;
}

fn atan32(z: Complex(f32)) Complex(f32) {
    const x = z.re;
    const y = z.im;

    const x2 = x * x;

    var a = 1 - x2 - (y * y);

    var t = 0.5 * math.atan2(2 * x, a);

    const w = redupif32(t);

    t = y - 1;
    a = x2 + t * t;

    t = y + 1;
    a = (x2 + (t * t)) / a;

    return .init(w, 0.25 * @log(a));
}

fn redupif64(x: f64) f64 {
    const dp1 = 3.14159265160560607910;
    const dp2 = 1.98418714791870343106e-9;
    const dp3 = 1.14423774522196636802e-17;

    var t = x / math.pi;

    if (t >= 0.0)
        t += 0.5
    else
        t -= 0.5;

    const u: f64 = @trunc(t);

    return ((x - u * dp1) - u * dp2) - u * dp3;
}

fn atan64(z: Complex(f64)) Complex(f64) {
    const x = z.re;
    const y = z.im;

    const x2 = x * x;

    var a = 1 - x2 - (y * y);

    var t = 0.5 * math.atan2(2 * x, a);

    const w = redupif64(t);

    t = y - 1;
    a = x2 + t * t;

    t = y + 1;
    a = (x2 + (t * t)) / a;

    return .init(w, 0.25 * @log(a));
}

test atan32 {
    const epsilon = math.floatEps(f32);

    const a: Complex(f32) = .init(5, 3);
    const atan_a = atan(a);

    try testing.expectApproxEqAbs(1.423679, atan_a.re, epsilon);
    try testing.expectApproxEqAbs(0.086569, atan_a.im, epsilon);
}

test atan64 {
    const epsilon = math.floatEps(f64);

    const a: Complex(f64) = .init(5, 3);
    const atan_a = atan(a);

    try testing.expectApproxEqAbs(1.4236790442393028, atan_a.re, epsilon);
    try testing.expectApproxEqAbs(0.08656905917945844, atan_a.im, epsilon);
}

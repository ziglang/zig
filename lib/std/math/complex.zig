//! Generic complex number functions.
//! Only the presence of a re and im
//! scalar fields are required. Types
//! with single or double floats have
//! guaranteed compatibility for all
//! functions contained in this file,
//! other numeric formats may receive
//! fallback implementations that are
//! less robust or behave incorrectly
//! in edge-cases, or are unsupported
//! entirely.

const std = @import("../std.zig");
const testing = std.testing;
const math = std.math;

/// deserialize tuple to complex type
pub fn as(comptime Z: type, z: anytype) Z {
    return .{ .re = z[0], .im = z[1] };
}

/// destructure to tuple ordered (real, imag)
pub fn reim(z: anytype) struct { @TypeOf(z.re), @TypeOf(z.im) } {
    return .{ z.re, z.im };
}

/// destructure to tuple ordered (imag, real)
pub fn imre(z: anytype) struct { @TypeOf(z.re), @TypeOf(z.im) } {
    return .{ z.im, z.re };
}

/// analyze zz*
pub fn abs2(z: anytype) @TypeOf(z.re, z.im) {
    return @mulAdd(@TypeOf(z.re, z.im), z.re, z.re, z.im * z.im);
}

/// analyze |z|
pub fn abs(z: anytype) @TypeOf(z.re, z.im) {
    return math.hypot(z.re, z.im);
}

/// analyze Im(log(z))
pub fn arg(z: anytype) @TypeOf(z.re, z.im) {
    return math.atan2(z.im, z.re);
}

/// analyze z as nepers and radians
pub fn log(z: anytype) @TypeOf(z) {
    return .{
        .re = @log(abs2(z)) * 0.5,
        .im = arg(z),
    };
}

/// compute iz*
pub fn flip(z: anytype) @TypeOf(z) {
    return .{
        .re = z.im,
        .im = z.re,
    };
}

/// compute z*
pub fn conj(z: anytype) @TypeOf(z) {
    return .{
        .re = z.re,
        .im = -z.im,
    };
}

/// compute -z
pub fn neg(z: anytype) @TypeOf(z) {
    return .{
        .re = -z.re,
        .im = -z.im,
    };
}

/// compute 1/z
pub fn inv(z: anytype) @TypeOf(z) {
    const zz = abs2(z);
    return .{
        .re = z.re / zz,
        .im = -z.im / zz,
    };
}

/// compute `cos(z.re + i*z.im) = cosh(iz)`
pub fn cos(z: anytype) @TypeOf(z) {
    return cosh(flip(conj(z)));
}

/// compute `sin(z.re + i*z.im) = -isinh(iz)`
pub fn sin(z: anytype) @TypeOf(z) {
    return conj(flip(sinh(flip(conj(z)))));
}

/// compute `tan(z.re + i*z.im) = -itanh(iz)`
pub fn tan(z: anytype) @TypeOf(z) {
    return conj(flip(tanh(flip(conj(z)))));
}

/// compute `arccosh(z.re + i*z.im) = log(z + sqrt(z*z - 1))`
pub fn acosh(z: anytype) @TypeOf(z) {
    const Z = @TypeOf(z.re, z.im);
    const s = sqrt(.{
        .re = @mulAdd(Z, z.re, z.re, -(z.im * z.im + 1)),
        .im = 2 * z.re * z.im,
    });
    return log(.{
        .re = z.re + s.re,
        .im = z.im + s.im,
    });
}

/// compute `arcsinh(z.re + i*z.im) = log(z + sqrt(z*z + 1))`
pub fn asinh(z: anytype) @TypeOf(z) {
    const Z = @TypeOf(z.re, z.im);
    const s = sqrt(.{
        .re = @mulAdd(Z, -z.im, z.im, z.re * z.re + 1),
        .im = 2 * z.re * z.im,
    });
    return log(.{
        .re = z.re + s.re,
        .im = z.im + s.im,
    });
}

/// compute `arctanh(z.re + i*z.im) = log( (1+z)/(1-z) ) / 2`
pub fn atanh(z: anytype) @TypeOf(z) {
    return flip(conj(atan(conj(flip(z)))));
}

/// compute `arccos(z.re + i*z.im) = -ilog(z + sqrt(z*z - 1))`
pub fn acos(z: anytype) @TypeOf(z) {
    return conj(flip(acosh(z)));
}

/// compute `arcsin(z.re + i*z.im) = -ilog(iz + sqrt(iz*iz + 1))`
pub fn asin(z: anytype) @TypeOf(z) {
    return conj(flip(asinh(flip(conj(z)))));
}

/// compute `arctan(z.re + i*z.im) = -ilog( (1+iz)/(1-iz) ) / 2`
pub fn atan(z: anytype) @TypeOf(z) {
    const impl = @import("complex/atan.zig");
    const Z = @TypeOf(z);
    return switch (@TypeOf(z.re, z.im)) {
        f32 => as(Z, impl.atan32(z.re, z.im)),
        f64 => as(Z, impl.atan64(z.re, z.im)),
        else => |S| as(Z, impl.atanFallback(S, z.re, z.im)),
    };
}

/// Computes the even part of the complex exponential function.
/// ```
///    z    -z
///  e   + e
/// ----------- = cosh(z.re)cos(z.im) + isinh(z.re)sin(z.im)
///      2
/// ```
pub fn cosh(z: anytype) @TypeOf(z) {
    const impl = @import("complex/cosh.zig");
    const Z = @TypeOf(z);
    return switch (@TypeOf(z.re, z.im)) {
        f32 => as(Z, impl.cosh32(z.re, z.im)),
        f64 => as(Z, impl.cosh64(z.re, z.im)),
        else => .{
            .re = math.cosh(z.re) * @cos(z.im),
            .im = math.sinh(z.re) * @sin(z.im),
        },
    };
}

/// Computes the odd part of the complex exponential function.
/// ```
///    z    -z
///  e   - e
/// ----------- = sinh(z.re)cos(z.im) + icosh(z.re)sin(z.im)
///      2
/// ```
pub fn sinh(z: anytype) @TypeOf(z) {
    const impl = @import("complex/sinh.zig");
    const Z = @TypeOf(z);
    return switch (@TypeOf(z.re, z.im)) {
        f32 => as(Z, impl.sinh32(z.re, z.im)),
        f64 => as(Z, impl.sinh64(z.re, z.im)),
        else => .{
            .re = math.sinh(z.re) * @cos(z.im),
            .im = math.cosh(z.re) * @sin(z.im),
        },
    };
}

/// Computes the asymmetry of the complex exponential function.
/// ```
///    z    -z
///  e   - e       cosh(z.re)sinh(z.re)/cos^2(z.im) + itan(z.im)
/// ----------- = -----------------------------------------------
///    z    -z             sinh^2(z.re)/cos^2(z.im) + 1
///  e   + e
/// ```
pub fn tanh(z: anytype) @TypeOf(z) {
    const impl = @import("complex/tanh.zig");
    const Z = @TypeOf(z);
    return switch (@TypeOf(z.re, z.im)) {
        f32 => as(Z, impl.tanh32(z.re, z.im)),
        f64 => as(Z, impl.tanh64(z.re, z.im)),
        else => |S| as(Z, impl.tanhFallback(S, z.re, z.im)),
    };
}

/// Composes a complex number from nepers and radians.
/// ```
///
///    z     z.re
///  e   = e      * ( cos(z.im) + i*sin(z.im) )
///
///
/// ```
/// Special Cases:
/// |  re  |  im  |   real  |   imag  |
/// |------|------|---------|---------|
/// |  any |   0  |   e^re  |    0    |
/// |   0  |  any | cos(im) | sin(im) |
/// | !inf | !fin |   nan   |   nan   |
/// | -inf | !fin |    0    |    0    |
/// | +inf | !fin |   inf   |   nan   |
pub fn exp(z: anytype) @TypeOf(z) {
    const impl = @import("complex/exp.zig");
    const Z = @TypeOf(z);
    return switch (@TypeOf(z.re, z.im)) {
        f32 => as(Z, impl.exp32(z.re, z.im)),
        f64 => as(Z, impl.exp64(z.re, z.im)),
        else => |S| as(Z, impl.expFallback(S, z.re, z.im)),
    };
}

/// compute the geometric mean between z and unity
pub fn sqrt(z: anytype) @TypeOf(z) {
    const impl = @import("complex/sqrt.zig");
    const Z = @TypeOf(z);
    return switch (@TypeOf(z.re, z.im)) {
        f32 => as(Z, impl.sqrt32(z.re, z.im)),
        f64 => as(Z, impl.sqrt64(z.re, z.im)),
        else => |S| as(Z, impl.sqrtFallback(S, z.re, z.im)),
    };
}

/// map non-zeros to unit-complex circle
pub fn sgn(z: anytype) @TypeOf(z) {
    const s = math.hypot(z.re, z.im);
    return if (s > 0) .{
        .re = z.re / s,
        .im = z.im / s,
    } else z;
}

/// map infinities to poles of Riemann sphere
pub fn proj(z: anytype) @TypeOf(z) {
    const F = @TypeOf(z.re, z.im);
    return if (math.isInf(z.re) or math.isInf(z.im)) .{
        .re = math.inf(F),
        .im = math.copysign(@as(F, 0.0), z.re),
    } else z;
}

/// compute a+b
pub fn add(comptime Z: type, a: anytype, b: anytype) Z {
    return .{
        .re = a.re + b.re,
        .im = a.im + b.im,
    };
}

/// compute a-b
pub fn sub(comptime Z: type, a: anytype, b: anytype) Z {
    return .{
        .re = a.re - b.re,
        .im = a.im - b.im,
    };
}

/// compute a*b
pub fn mul(comptime Z: type, a: anytype, b: anytype) Z {
    return .{
        .re = a.re * b.re - a.im * b.im,
        .im = a.im * b.re + a.re * b.im,
    };
}

/// compute a/b
pub fn div(comptime Z: type, a: anytype, b: anytype) Z {
    const bb = abs2(b);
    return .{
        .re = (a.re * b.re + a.im * b.im) / bb,
        .im = (a.im * b.re - a.re * b.im) / bb,
    };
}

/// compute a^b
pub fn pow(comptime Z: type, a: anytype, b: anytype) Z {
    const amp, const phs = reim(log(a));
    return exp(.{
        .re = b.re * amp - b.im * phs,
        .im = b.re * phs + b.im * amp,
    });
}

/// Generic formatter that can be declared in custom types.
/// Requires presence of a scalar real and imaginary field.
pub fn format(
    z: anytype,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    if (z.im < 0 or 1 / z.im < 0) return writer.print("{d} - {d}im", .{ z.re, @abs(z.im) });
    return writer.print("{d} + {d}im", .{ z.re, z.im });
}

/// Validate a type or value to be compatible with complex functions.
/// Returns true if all complex functions are guaranteed to work.
/// Returns false if some complex functions may be incompatible.
pub inline fn isComplex(z: anytype) bool {
    const Z = if (type == @TypeOf(z)) z else @TypeOf(z);
    if (!@hasField(Z, "re")) return false;
    if (!@hasField(Z, "im")) return false;
    const s: Z = .{ .re = 0, .im = 0 };
    if (f32 != @TypeOf(s.re) and f64 != @TypeOf(s.re)) return false;
    if (f32 != @TypeOf(s.im) and f64 != @TypeOf(s.im)) return false;
    return true;
}

test as {
    const re: f32 = 1 / 3;
    const im: f32 = 1 / 5;
    const Z = struct { re: f32, im: f32 };
    const z = as(Z, .{ re, im });
    try testing.expect(re == z.re);
    try testing.expect(im == z.im);
}

test reim {
    const z = .{ .re = 1 / 3, .im = 1 / 5 };
    const re, const im = reim(z);
    try testing.expect(re == z.re);
    try testing.expect(im == z.im);
}

test imre {
    const z = .{ .re = 1 / 3, .im = 1 / 5 };
    const im, const re = imre(z);
    try testing.expect(re == z.re);
    try testing.expect(im == z.im);
}

test abs2 {
    const re: f32 = 3;
    const im: f32 = 4;
    const Z = struct { re: f32, im: f32 };
    try testing.expect(abs2(as(Z, .{ re, im })) == 25);
}

test abs {
    const re: f32 = 1 / 3;
    const im: f32 = 1 / 5;
    const Z = struct { re: f32, im: f32 };
    try testing.expect(abs(as(Z, .{ re, im })) == math.hypot(re, im));
}

test arg {
    const re: f32 = 1 / 3;
    const im: f32 = 1 / 5;
    const Z = struct { re: f32, im: f32 };
    try testing.expect(arg(as(Z, .{ re, im })) == math.atan2(re, im));
}

test log {
    const re: f32 = 1 / 3;
    const im: f32 = 1 / 5;
    const Z = struct { re: f32, im: f32 };
    const z = as(Z, .{ re, im });
    const s = log(z);
    try testing.expect(s.re == @log(abs(z)));
    try testing.expect(s.im == arg(z));
}

test flip {
    const re: f32 = 1 / 3;
    const im: f32 = 1 / 5;
    const Z = struct { re: f32, im: f32 };
    const z = flip(as(Z, .{ re, im }));
    try testing.expect(re == z.im);
    try testing.expect(im == z.re);
}

test conj {
    const re: f32 = 1 / 3;
    const im: f32 = 1 / 5;
    const Z = struct { re: f32, im: f32 };
    const z = conj(as(Z, .{ re, im }));
    try testing.expect(re == z.re);
    try testing.expect(im == -z.im);
}

test neg {
    const re: f32 = 1 / 3;
    const im: f32 = 1 / 5;
    const Z = struct { re: f32, im: f32 };
    const z = neg(as(Z, .{ re, im }));
    try testing.expect(re == -z.re);
    try testing.expect(im == -z.im);
}

test inv {
    const Z = struct { re: f32, im: f32 };
    const z = inv(as(Z, .{ 5, 3 }));
    const re: f32 = 0.14705882352941177;
    const im: f32 = -0.08823529411764706;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test exp {
    const Z = struct { re: f32, im: f32 };
    const z = exp(as(Z, .{ 5, 3 }));
    const re: f32 = -146.92791390831894;
    const im: f32 = 20.944066208745966;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test cos {
    const Z = struct { re: f32, im: f32 };
    const z = cos(as(Z, .{ 5, 3 }));
    const re: f32 = 2.855815004227387;
    const im: f32 = 9.606383448432581;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test sin {
    const Z = struct { re: f32, im: f32 };
    const z = sin(as(Z, .{ 5, 3 }));
    const re: f32 = -9.654125476854839;
    const im: f32 = 2.841692295606352;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test tan {
    const Z = struct { re: f32, im: f32 };
    const z = tan(as(Z, .{ 5, 3 }));
    const re: f32 = -0.0027082358362240716;
    const im: f32 = 1.0041647106948153;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test cosh {
    const Z = struct { re: f32, im: f32 };
    const z = cosh(as(Z, .{ 5, 3 }));
    const re: f32 = -73.46729221264526;
    const im: f32 = 10.471557674805572;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test sinh {
    const Z = struct { re: f32, im: f32 };
    const z = sinh(as(Z, .{ 5, 3 }));
    const re: f32 = -73.46062169567367;
    const im: f32 = 10.472508533940392;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test tanh {
    const Z = struct { re: f32, im: f32 };
    const z = tanh(as(Z, .{ 5, 3 }));
    const re: f32 = 0.9999128201513536;
    const im: f32 = -2.536867620767604e-5;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test acos {
    const Z = struct { re: f32, im: f32 };
    const z = acos(as(Z, .{ 5, 3 }));
    const re: f32 = 0.5469745802831136;
    const im: f32 = -2.452913742502812;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test asin {
    const Z = struct { re: f32, im: f32 };
    const z = asin(as(Z, .{ 5, 3 }));
    const re: f32 = 1.023821746511783;
    const im: f32 = 2.452913742502812;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test atan {
    const Z = struct { re: f32, im: f32 };
    const z = atan(as(Z, .{ 5, 3 }));
    const re: f32 = 1.4236790442393028;
    const im: f32 = 0.08656905917945844;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test acosh {
    const Z = struct { re: f32, im: f32 };
    const z = acosh(as(Z, .{ 5, 3 }));
    const re: f32 = 2.452913742502812;
    const im: f32 = 0.5469745802831136;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test asinh {
    const Z = struct { re: f32, im: f32 };
    const z = asinh(as(Z, .{ 5, 3 }));
    const re: f32 = 2.4598315216234345;
    const im: f32 = 0.5339990695941687;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test atanh {
    const Z = struct { re: f32, im: f32 };
    const z = atanh(as(Z, .{ 5, 3 }));
    const re: f32 = 0.14694666622552977;
    const im: f32 = 1.4808695768986575;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test sqrt {
    const Z = struct { re: f32, im: f32 };
    const z = sqrt(as(Z, .{ 5, 3 }));
    const re: f32 = 2.3271175190399496;
    const im: f32 = 0.6445742373246469;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test sgn {
    const Z = struct { re: f32, im: f32 };
    const z = sgn(as(Z, .{ 5, 3 }));
    const re: f32 = 0.8574929257125441;
    const im: f32 = 0.5144957554275265;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test proj {
    const Z = struct { re: f32, im: f32 };
    const z = proj(as(Z, .{ 1, math.inf(f32) }));
    try testing.expect(z.re == math.inf(f32));
    try testing.expect(z.im == 0);
}

test add {
    const Z = struct { re: f32, im: f32 };
    const z = add(Z, as(Z, .{ 5, 3 }), as(Z, .{ 3, 5 }));
    const re: f32 = 8;
    const im: f32 = 8;
    try testing.expect(re == z.re);
    try testing.expect(im == z.im);
}

test sub {
    const Z = struct { re: f32, im: f32 };
    const z = sub(Z, as(Z, .{ 5, 3 }), as(Z, .{ 3, 5 }));
    const re: f32 = 2;
    const im: f32 = -2;
    try testing.expect(re == z.re);
    try testing.expect(im == z.im);
}

test mul {
    const Z = struct { re: f32, im: f32 };
    const z = mul(Z, as(Z, .{ 5, 3 }), as(Z, .{ 3, 5 }));
    const re: f32 = 0;
    const im: f32 = 34;
    try testing.expect(re == z.re);
    try testing.expect(im == z.im);
}

test div {
    const Z = struct { re: f32, im: f32 };
    const z = div(Z, as(Z, .{ 5, 3 }), as(Z, .{ 3, 5 }));
    const re: f32 = 0.8823529411764706;
    const im: f32 = -0.4705882352941177;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test pow {
    const Z = struct { re: f32, im: f32 };
    const z = pow(Z, as(Z, .{ 5, 3 }), as(Z, .{ 3, 5 }));
    const re: f32 = -7.04464115622119;
    const im: f32 = -11.276062812695923;
    try testing.expect(math.approxEqAbs(f32, z.re, re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z.im, im, @sqrt(math.floatEpsAt(f32, im))));
}

test isComplex {
    const Z = struct { re: f32, im: f32 };
    const z: Z = .{ .re = 0, .im = 0 };
    try testing.expect(isComplex(Z));
    try testing.expect(isComplex(z));
    const F = if (isComplex(Z)) f32 else f64;
    const f = if (isComplex(z)) @as(f32, 1) else @as(f64, 1);
    try testing.expect(f32 == F);
    try testing.expect(f32 == @TypeOf(f));
}

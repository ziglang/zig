const std = @import("std");
const isNan = std.math.isNan;
const isInf = std.math.isInf;
const scalbn = std.math.scalbn;
const ilogb = std.math.ilogb;
const fabs = std.math.fabs;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const isFinite = std.math.isFinite;
const copysign = std.math.copysign;
const Complex = @import("mulc3.zig").Complex;

/// Implementation based on Annex G of C17 Standard (N2176)
pub inline fn divc3(comptime T: type, a: T, b: T, c_in: T, d_in: T) Complex(T) {
    var c = c_in;
    var d = d_in;

    // logbw used to prevent under/over-flow
    const logbw = ilogb(@max(fabs(c), fabs(d)));
    const logbw_finite = logbw != maxInt(i32) and logbw != minInt(i32);
    const ilogbw = if (logbw_finite) b: {
        c = scalbn(c, -logbw);
        d = scalbn(d, -logbw);
        break :b logbw;
    } else 0;
    const denom = c * c + d * d;
    const result = Complex(T){
        .real = scalbn((a * c + b * d) / denom, -ilogbw),
        .imag = scalbn((b * c - a * d) / denom, -ilogbw),
    };

    // Recover infinities and zeros that computed as NaN+iNaN;
    // the only cases are non-zero/zero, infinite/finite, and finite/infinite, ...
    if (isNan(result.real) and isNan(result.imag)) {
        const zero: T = 0.0;
        const one: T = 1.0;

        if ((denom == 0.0) and (!isNan(a) or !isNan(b))) {
            return .{
                .real = copysign(std.math.inf(T), c) * a,
                .imag = copysign(std.math.inf(T), c) * b,
            };
        } else if ((isInf(a) or isInf(b)) and isFinite(c) and isFinite(d)) {
            const boxed_a = copysign(if (isInf(a)) one else zero, a);
            const boxed_b = copysign(if (isInf(b)) one else zero, b);
            return .{
                .real = std.math.inf(T) * (boxed_a * c - boxed_b * d),
                .imag = std.math.inf(T) * (boxed_b * c - boxed_a * d),
            };
        } else if (logbw == maxInt(i32) and isFinite(a) and isFinite(b)) {
            const boxed_c = copysign(if (isInf(c)) one else zero, c);
            const boxed_d = copysign(if (isInf(d)) one else zero, d);
            return .{
                .real = 0.0 * (a * boxed_c + b * boxed_d),
                .imag = 0.0 * (b * boxed_c - a * boxed_d),
            };
        }
    }

    return result;
}

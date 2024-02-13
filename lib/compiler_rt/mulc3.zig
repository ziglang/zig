const std = @import("std");
const isNan = std.math.isNan;
const isInf = std.math.isInf;
const copysign = std.math.copysign;

pub fn Complex(comptime T: type) type {
    return extern struct {
        real: T,
        imag: T,
    };
}

/// Implementation based on Annex G of C17 Standard (N2176)
pub inline fn mulc3(comptime T: type, a_in: T, b_in: T, c_in: T, d_in: T) Complex(T) {
    var a = a_in;
    var b = b_in;
    var c = c_in;
    var d = d_in;

    const ac = a * c;
    const bd = b * d;
    const ad = a * d;
    const bc = b * c;

    const zero: T = 0.0;
    const one: T = 1.0;

    const z: Complex(T) = .{
        .real = ac - bd,
        .imag = ad + bc,
    };
    if (isNan(z.real) and isNan(z.imag)) {
        var recalc: bool = false;

        if (isInf(a) or isInf(b)) { // (a + ib) is infinite

            // "Box" the infinity (+/-inf goes to +/-1, all finite values go to 0)
            a = copysign(if (isInf(a)) one else zero, a);
            b = copysign(if (isInf(b)) one else zero, b);

            // Replace NaNs in the other factor with (signed) 0
            if (isNan(c)) c = copysign(zero, c);
            if (isNan(d)) d = copysign(zero, d);

            recalc = true;
        }

        if (isInf(c) or isInf(d)) { // (c + id) is infinite

            // "Box" the infinity (+/-inf goes to +/-1, all finite values go to 0)
            c = copysign(if (isInf(c)) one else zero, c);
            d = copysign(if (isInf(d)) one else zero, d);

            // Replace NaNs in the other factor with (signed) 0
            if (isNan(a)) a = copysign(zero, a);
            if (isNan(b)) b = copysign(zero, b);

            recalc = true;
        }

        if (!recalc and (isInf(ac) or isInf(bd) or isInf(ad) or isInf(bc))) {

            // Recover infinities from overflow by changing NaNs to 0
            if (isNan(a)) a = copysign(zero, a);
            if (isNan(b)) b = copysign(zero, b);
            if (isNan(c)) c = copysign(zero, c);
            if (isNan(d)) d = copysign(zero, d);

            recalc = true;
        }
        if (recalc) {
            return .{
                .real = std.math.inf(T) * (a * c - b * d),
                .imag = std.math.inf(T) * (a * d + b * c),
            };
        }
    }
    return z;
}

// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/__rem_pio2.c

const std = @import("std");
const rem_pio2_large = @import("rem_pio2_large.zig").rem_pio2_large;
const math = std.math;

const toint = 1.5 / math.floatEps(f64);
// pi/4
const pio4 = 0x1.921fb54442d18p-1;
// invpio2:  53 bits of 2/pi
const invpio2 = 6.36619772367581382433e-01; // 0x3FE45F30, 0x6DC9C883
// pio2_1:   first  33 bit of pi/2
const pio2_1 = 1.57079632673412561417e+00; // 0x3FF921FB, 0x54400000
// pio2_1t:  pi/2 - pio2_1
const pio2_1t = 6.07710050650619224932e-11; // 0x3DD0B461, 0x1A626331
// pio2_2:   second 33 bit of pi/2
const pio2_2 = 6.07710050630396597660e-11; // 0x3DD0B461, 0x1A600000
// pio2_2t:  pi/2 - (pio2_1+pio2_2)
const pio2_2t = 2.02226624879595063154e-21; // 0x3BA3198A, 0x2E037073
// pio2_3:   third  33 bit of pi/2
const pio2_3 = 2.02226624871116645580e-21; // 0x3BA3198A, 0x2E000000
// pio2_3t:  pi/2 - (pio2_1+pio2_2+pio2_3)
const pio2_3t = 8.47842766036889956997e-32; // 0x397B839A, 0x252049C1

fn U(x: anytype) usize {
    return @as(usize, @intCast(x));
}

fn medium(ix: u32, x: f64, y: *[2]f64) i32 {
    var w: f64 = undefined;
    var t: f64 = undefined;
    var r: f64 = undefined;
    var @"fn": f64 = undefined;
    var n: i32 = undefined;
    var ex: i32 = undefined;
    var ey: i32 = undefined;
    var ui: u64 = undefined;

    // rint(x/(pi/2))
    @"fn" = x * invpio2 + toint - toint;
    n = @as(i32, @intFromFloat(@"fn"));
    r = x - @"fn" * pio2_1;
    w = @"fn" * pio2_1t; // 1st round, good to 85 bits
    // Matters with directed rounding.
    if (r - w < -pio4) {
        n -= 1;
        @"fn" -= 1;
        r = x - @"fn" * pio2_1;
        w = @"fn" * pio2_1t;
    } else if (r - w > pio4) {
        n += 1;
        @"fn" += 1;
        r = x - @"fn" * pio2_1;
        w = @"fn" * pio2_1t;
    }
    y[0] = r - w;
    ui = @bitCast(y[0]);
    ey = @intCast((ui >> 52) & 0x7ff);
    ex = @intCast(ix >> 20);
    if (ex - ey > 16) { // 2nd round, good to 118 bits
        t = r;
        w = @"fn" * pio2_2;
        r = t - w;
        w = @"fn" * pio2_2t - ((t - r) - w);
        y[0] = r - w;
        ui = @bitCast(y[0]);
        ey = @intCast((ui >> 52) & 0x7ff);
        if (ex - ey > 49) { // 3rd round, good to 151 bits, covers all cases
            t = r;
            w = @"fn" * pio2_3;
            r = t - w;
            w = @"fn" * pio2_3t - ((t - r) - w);
            y[0] = r - w;
        }
    }
    y[1] = (r - y[0]) - w;
    return n;
}

// Returns the remainder of x rem pi/2 in y[0]+y[1]
//
// use rem_pio2_large() for large x
//
// caller must handle the case when reduction is not needed: |x| ~<= pi/4 */
pub fn rem_pio2(x: f64, y: *[2]f64) i32 {
    var z: f64 = undefined;
    var tx: [3]f64 = undefined;
    var ty: [2]f64 = undefined;
    var n: i32 = undefined;
    var ix: u32 = undefined;
    var sign: bool = undefined;
    var i: i32 = undefined;
    var ui: u64 = undefined;

    ui = @bitCast(x);
    sign = ui >> 63 != 0;
    ix = @truncate((ui >> 32) & 0x7fffffff);
    if (ix <= 0x400f6a7a) { // |x| ~<= 5pi/4
        if ((ix & 0xfffff) == 0x921fb) { // |x| ~= pi/2 or 2pi/2
            return medium(ix, x, y);
        }
        if (ix <= 0x4002d97c) { // |x| ~<= 3pi/4
            if (!sign) {
                z = x - pio2_1; // one round good to 85 bits
                y[0] = z - pio2_1t;
                y[1] = (z - y[0]) - pio2_1t;
                return 1;
            } else {
                z = x + pio2_1;
                y[0] = z + pio2_1t;
                y[1] = (z - y[0]) + pio2_1t;
                return -1;
            }
        } else {
            if (!sign) {
                z = x - 2 * pio2_1;
                y[0] = z - 2 * pio2_1t;
                y[1] = (z - y[0]) - 2 * pio2_1t;
                return 2;
            } else {
                z = x + 2 * pio2_1;
                y[0] = z + 2 * pio2_1t;
                y[1] = (z - y[0]) + 2 * pio2_1t;
                return -2;
            }
        }
    }
    if (ix <= 0x401c463b) { // |x| ~<= 9pi/4
        if (ix <= 0x4015fdbc) { // |x| ~<= 7pi/4
            if (ix == 0x4012d97c) { // |x| ~= 3pi/2
                return medium(ix, x, y);
            }
            if (!sign) {
                z = x - 3 * pio2_1;
                y[0] = z - 3 * pio2_1t;
                y[1] = (z - y[0]) - 3 * pio2_1t;
                return 3;
            } else {
                z = x + 3 * pio2_1;
                y[0] = z + 3 * pio2_1t;
                y[1] = (z - y[0]) + 3 * pio2_1t;
                return -3;
            }
        } else {
            if (ix == 0x401921fb) { // |x| ~= 4pi/2 */
                return medium(ix, x, y);
            }
            if (!sign) {
                z = x - 4 * pio2_1;
                y[0] = z - 4 * pio2_1t;
                y[1] = (z - y[0]) - 4 * pio2_1t;
                return 4;
            } else {
                z = x + 4 * pio2_1;
                y[0] = z + 4 * pio2_1t;
                y[1] = (z - y[0]) + 4 * pio2_1t;
                return -4;
            }
        }
    }
    if (ix < 0x413921fb) { // |x| ~< 2^20*(pi/2), medium size
        return medium(ix, x, y);
    }
    // all other (large) arguments
    if (ix >= 0x7ff00000) { // x is inf or NaN
        y[0] = x - x;
        y[1] = y[0];
        return 0;
    }
    // set z = scalbn(|x|,-ilogb(x)+23)
    ui = @bitCast(x);
    ui &= std.math.maxInt(u64) >> 12;
    ui |= @as(u64, 0x3ff + 23) << 52;
    z = @as(f64, @bitCast(ui));

    i = 0;
    while (i < 2) : (i += 1) {
        tx[U(i)] = @as(f64, @floatFromInt(@as(i32, @intFromFloat(z))));
        z = (z - tx[U(i)]) * 0x1p24;
    }
    tx[U(i)] = z;
    // skip zero terms, first term is non-zero
    while (tx[U(i)] == 0.0) {
        i -= 1;
    }
    n = rem_pio2_large(tx[0..], ty[0..], @as(i32, @intCast((ix >> 20))) - (0x3ff + 23), i + 1, 1);
    if (sign) {
        y[0] = -ty[0];
        y[1] = -ty[1];
        return -n;
    }
    y[0] = ty[0];
    y[1] = ty[1];
    return n;
}

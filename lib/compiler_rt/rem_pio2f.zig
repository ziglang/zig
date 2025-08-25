// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/__rem_pio2f.c

const std = @import("std");
const rem_pio2_large = @import("rem_pio2_large.zig").rem_pio2_large;
const math = std.math;

const toint = 1.5 / math.floatEps(f64);
// pi/4
const pio4 = 0x1.921fb6p-1;
// invpio2:  53 bits of 2/pi
const invpio2 = 6.36619772367581382433e-01; // 0x3FE45F30, 0x6DC9C883
// pio2_1:   first 25 bits of pi/2
const pio2_1 = 1.57079631090164184570e+00; // 0x3FF921FB, 0x50000000
// pio2_1t:  pi/2 - pio2_1
const pio2_1t = 1.58932547735281966916e-08; // 0x3E5110b4, 0x611A6263

// Returns the remainder of x rem pi/2 in *y
// use double precision for everything except passing x
// use rem_pio2_large() for large x
pub fn rem_pio2f(x: f32, y: *f64) i32 {
    var tx: [1]f64 = undefined;
    var ty: [1]f64 = undefined;
    var @"fn": f64 = undefined;
    var ix: u32 = undefined;
    var n: i32 = undefined;
    var sign: bool = undefined;
    var e0: u32 = undefined;
    var ui: u32 = undefined;

    ui = @bitCast(x);
    ix = ui & 0x7fffffff;

    // 25+53 bit pi is good enough for medium size
    if (ix < 0x4dc90fdb) { // |x| ~< 2^28*(pi/2), medium size
        // Use a specialized rint() to get fn.
        @"fn" = @as(f64, @floatCast(x)) * invpio2 + toint - toint;
        n = @intFromFloat(@"fn");
        y.* = x - @"fn" * pio2_1 - @"fn" * pio2_1t;
        // Matters with directed rounding.
        if (y.* < -pio4) {
            n -= 1;
            @"fn" -= 1;
            y.* = x - @"fn" * pio2_1 - @"fn" * pio2_1t;
        } else if (y.* > pio4) {
            n += 1;
            @"fn" += 1;
            y.* = x - @"fn" * pio2_1 - @"fn" * pio2_1t;
        }
        return n;
    }
    if (ix >= 0x7f800000) { // x is inf or NaN
        y.* = x - x;
        return 0;
    }
    // scale x into [2^23, 2^24-1]
    sign = ui >> 31 != 0;
    e0 = (ix >> 23) - (0x7f + 23); // e0 = ilogb(|x|)-23, positive
    ui = ix - (e0 << 23);
    tx[0] = @as(f32, @bitCast(ui));
    n = rem_pio2_large(&tx, &ty, @as(i32, @intCast(e0)), 1, 0);
    if (sign) {
        y.* = -ty[0];
        return -n;
    }
    y.* = ty[0];
    return n;
}

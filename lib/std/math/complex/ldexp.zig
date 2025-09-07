//! Ported from musl, which is licensed under the MIT license:
//! https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//!
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/__cexpf.c
//! https://git.musl-libc.org/cgit/musl/tree/src/complex/__cexp.c

const std = @import("../../std.zig");
const debug = std.debug;
const math = std.math;
const testing = std.testing;
const Complex = math.Complex;

/// Calculates scaled exp of a complex number to avoid overflow.
pub fn ldexp(z: anytype, expt: i32) Complex(@TypeOf(z.re, z.im)) {
    const T = @TypeOf(z.re, z.im);

    return switch (T) {
        f32 => ldexp32(z, expt),
        f64 => ldexp64(z, expt),
        else => @compileError("ldexp not implemented for " ++ @typeName(T)),
    };
}

fn frexp32(x: f32, expt: *i32) f32 {
    const k = 235; // Constant for reducation
    const kln2 = 162.88958740; // k * ln2

    const exp_x = @exp(x - kln2);
    const hx: u32 = @bitCast(exp_x);

    // TODO: zig should allow this cast implicitly because it should know the value is in range
    expt.* = @as(i32, @intCast(hx >> 23)) - (0x7f + 127) + k;

    return @bitCast((hx & 0x7fffff) | ((0x7f + 127) << 23));
}

fn ldexp32(z: Complex(f32), expt: i32) Complex(f32) {
    const x = z.re;
    const y = z.im;

    var ex_expt: i32 = undefined;

    const exp_x = frexp32(x, &ex_expt);

    const exptf = expt + ex_expt;

    const half_expt1 = @divTrunc(exptf, 2);
    const scale1: f32 = @bitCast((0x7f + half_expt1) << 23);

    const half_expt2 = exptf - half_expt1;
    const scale2: f32 = @bitCast((0x7f + half_expt2) << 23);

    return .init(
        @cos(y) * exp_x * scale1 * scale2,
        @sin(y) * exp_x * scale1 * scale2,
    );
}

fn frexp64(x: f64, expt: *i32) f64 {
    const k = 1799; // Constant for reducation
    const kln2 = 1246.97177782734161156; // k * ln2

    const exp_x = @exp(x - kln2);

    const fx: u64 = @bitCast(exp_x);
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);

    expt.* = @as(i32, @intCast(hx >> 20)) - (0x3ff + 1023) + k;

    const high_word: u64 = (hx & 0xfffff) | ((0x3ff + 1023) << 20);

    return @bitCast((high_word << 32) | lx);
}

fn ldexp64(z: Complex(f64), expt: i32) Complex(f64) {
    const x = z.re;
    const y = z.im;

    var ex_expt: i32 = undefined;

    const exp_x = frexp64(x, &ex_expt);

    const exptf: i64 = expt + ex_expt;

    const half_expt1 = @divTrunc(exptf, 2);
    const scale1: f64 = @bitCast((0x3ff + half_expt1) << (20 + 32));

    const half_expt2 = exptf - half_expt1;
    const scale2: f64 = @bitCast((0x3ff + half_expt2) << (20 + 32));

    return .init(
        @cos(y) * exp_x * scale1 * scale2,
        @sin(y) * exp_x * scale1 * scale2,
    );
}
